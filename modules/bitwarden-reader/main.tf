# Note: Namespace is created by the bitwarden module, so we don't create it here
# We just reference it via var.namespace

# Register Helm repository for bitwarden-reader in ArgoCD
resource "kubectl_manifest" "bitwarden_reader_helm_repo" {
  count = var.enable ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "bitwarden-reader-chart-repo"
      namespace = var.argocd_namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "bitwarden-reader-chart"
      url     = "https://k8sforge.github.io/bitwarden-reader-chart"
      project = "default"
    }
  })
}

# ArgoCD Application for Bitwarden Reader
resource "kubectl_manifest" "bitwarden_reader_application" {
  count = var.enable ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = var.app_name
      namespace  = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://k8sforge.github.io/bitwarden-reader-chart"
        chart          = "bitwarden-reader"
        targetRevision = var.chart_version != null ? var.chart_version : "*"

        helm = {
          values = yamlencode({
            namespace = {
              name   = var.namespace
              create = false # Namespace is created by Terraform
            }
            image = {
              repository = length(split(":", var.image)) > 1 ? split(":", var.image)[0] : var.image
              tag        = length(split(":", var.image)) > 1 ? split(":", var.image)[1] : "latest"
              pullPolicy = var.image_pull_policy
            }
            replicaCount = 1 # Single replica, no HA needed
            app = {
              secretNames = var.secret_names
            }
            service = {
              enabled = true
              type    = "ClusterIP"
              port    = 8080
              name    = var.app_name # Ensure service name matches what we reference in ingress
            }
            ingress = {
              enabled = false # Disable ingress in helm chart - we'll create a dedicated ingress resource
            }
            livenessProbe = {
              httpGet = {
                path = "/api/v1/health"
                port = 8080
              }
              initialDelaySeconds = 60
              periodSeconds       = 30
              timeoutSeconds      = 5
              failureThreshold    = 3
            }
            readinessProbe = {
              httpGet = {
                path = "/api/v1/health"
                port = 8080
              }
              initialDelaySeconds = 60
              periodSeconds       = 10
              timeoutSeconds      = 5
              failureThreshold    = 3
            }
          })
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }

      ignoreDifferences = [
        {
          group        = "apps"
          kind         = "Deployment"
          jsonPointers = ["/status"]
        },
        {
          group        = "networking.k8s.io"
          kind         = "Ingress"
          jsonPointers = ["/status"]
        }
      ]
    }
  })

  wait = true

  depends_on = [
    kubectl_manifest.bitwarden_reader_helm_repo[0]
  ]
}

# Nginx proxy for path rewriting
# Rewrites /reader/* to /* before proxying to bitwarden-reader service
resource "kubectl_manifest" "bitwarden_reader_nginx_proxy" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "${var.app_name}-nginx-proxy"
      namespace = var.namespace
      labels = {
        app = "${var.app_name}-nginx-proxy"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "${var.app_name}-nginx-proxy"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "${var.app_name}-nginx-proxy"
          }
        }
        spec = {
          containers = [
            {
              name  = "nginx"
              image = "nginx:alpine"
              ports = [
                {
                  containerPort = 80
                  name          = "http"
                }
              ]
              volumeMounts = [
                {
                  name      = "nginx-config"
                  mountPath = "/etc/nginx/conf.d"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "nginx-config"
              configMap = {
                name = "${var.app_name}-nginx-proxy-config"
              }
            }
          ]
        }
      }
    }
  })

  depends_on = [kubectl_manifest.bitwarden_reader_application[0]]
}

# Nginx configuration for path rewriting
resource "kubectl_manifest" "bitwarden_reader_nginx_config" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "${var.app_name}-nginx-proxy-config"
      namespace = var.namespace
    }
    data = {
      "default.conf" = <<-EOT
        server {
          listen 80;

          # Catch /api requests (from JavaScript constructing absolute URLs) and proxy directly
          # API calls can't be redirected, so we proxy directly to backend /api
          location /api/ {
            proxy_pass http://${var.app_name}:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Prefix ${var.path_prefix};
            proxy_read_timeout 30;
          }

          # Catch /ws requests (from JavaScript constructing absolute URLs) and proxy directly
          # WebSocket connections can't be redirected, so we proxy directly to backend /ws
          location = /ws {
            proxy_pass http://${var.app_name}:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_read_timeout 86400;
          }

          # WebSocket endpoint - must be before the general location block
          location ${var.path_prefix}/ws {
            rewrite ^${var.path_prefix}/ws(.*)$ /ws$1 break;
            proxy_pass http://${var.app_name}:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_read_timeout 86400;
          }

          # Rewrite path prefix to /* before proxying to bitwarden-reader
          location ${var.path_prefix}/ {
            rewrite ^${var.path_prefix}/(.*)$ /$1 break;
            proxy_pass http://${var.app_name}:8080;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Prefix ${var.path_prefix};

            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;

            # Enable buffering for sub_filter to work
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
            proxy_busy_buffers_size 8k;

            # Rewrite HTML/JS content to fix absolute paths in CSS/JS/API references
            sub_filter 'href="/' 'href="${var.path_prefix}/';
            sub_filter "href='/" "href='${var.path_prefix}/";
            sub_filter 'src="/' 'src="${var.path_prefix}/';
            sub_filter "src='/" "src='${var.path_prefix}/";
            sub_filter 'action="/' 'action="${var.path_prefix}/';
            sub_filter "action='/" "action='${var.path_prefix}/";
            # Rewrite API URLs in JavaScript
            sub_filter '"/api/' '"${var.path_prefix}/api/';
            sub_filter "'/api/" "'${var.path_prefix}/api/";
            sub_filter '"/api"' '"${var.path_prefix}/api';
            sub_filter "'/api'" "'${var.path_prefix}/api";
            sub_filter_once off;
            sub_filter_types text/html text/css text/javascript application/javascript application/json text/plain;
          }

          # Redirect path prefix without trailing slash to path with trailing slash
          location = ${var.path_prefix} {
            return 301 ${var.path_prefix}/;
          }
        }
      EOT
    }
  })

  depends_on = [kubectl_manifest.bitwarden_reader_application[0]]
}

# Service for nginx proxy
resource "kubectl_manifest" "bitwarden_reader_nginx_service" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "${var.app_name}-nginx-proxy"
      namespace = var.namespace
      labels = {
        app = "${var.app_name}-nginx-proxy"
      }
    }
    spec = {
      type = "ClusterIP"
      ports = [
        {
          port       = 80
          targetPort = 80
          protocol   = "TCP"
          name       = "http"
        }
      ]
      selector = {
        app = "${var.app_name}-nginx-proxy"
      }
    }
  })

  depends_on = [
    kubectl_manifest.bitwarden_reader_nginx_proxy[0],
    kubectl_manifest.bitwarden_reader_nginx_config[0]
  ]
}

# Ingress resource for Bitwarden Reader using shared ALB
resource "kubectl_manifest" "bitwarden_reader_ingress" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = var.app_name
      namespace = var.namespace
      annotations = merge(
        {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path" = "${var.path_prefix}/api/v1/health"
          "alb.ingress.kubernetes.io/group.name"       = var.shared_alb_ingress_group_name
        },
        # Security group for IP restrictions (if provided)
        var.shared_alb_security_group_id != "" ? {
          "alb.ingress.kubernetes.io/security-groups" = var.shared_alb_security_group_id
        } : {},
        # HTTP-only configuration
        !var.enable_https ? {
          "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
        } : {},
        # HTTPS configuration (base)
        var.enable_https ? {
          "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
          "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
          "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        } : {},
        # HTTPS redirect (optional)
        var.enable_https && var.ssl_redirect ? {
          "alb.ingress.kubernetes.io/ssl-redirect" = "443"
        } : {}
      )
    }
    spec = {
      ingressClassName = "alb"
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/api"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "${var.app_name}-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              },
              {
                path     = "/ws"
                pathType = "Exact"
                backend = {
                  service = {
                    name = "${var.app_name}-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              },
              {
                path     = "${var.path_prefix}/api/v1/health"
                pathType = "Exact"
                backend = {
                  service = {
                    name = "${var.app_name}-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              },
              {
                path     = "${var.path_prefix}/ws"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "${var.app_name}-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              },
              {
                path     = "${var.path_prefix}/api"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "${var.app_name}-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              },
              {
                path     = var.path_prefix
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "${var.app_name}-nginx-proxy"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.bitwarden_reader_nginx_service[0]
  ]
}

data "kubernetes_ingress_v1" "reader" {
  count = var.enable && var.shared_alb_ingress_group_name != "" ? 1 : 0

  metadata {
    name      = var.app_name
    namespace = var.namespace
  }

  depends_on = [kubectl_manifest.bitwarden_reader_ingress[0]]
}
