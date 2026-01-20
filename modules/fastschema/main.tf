# Register Helm repository for FastSchema in ArgoCD
resource "kubectl_manifest" "fastschema_helm_repo" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "fastschema-chart-repo"
      namespace = var.argocd_namespace
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "helm"
      name    = "fastschema-chart"
      url     = "https://k8sforge.github.io/fastschema-chart"
      project = "default"
    }
  })
}

# ArgoCD Application for FastSchema
resource "kubectl_manifest" "fastschema_application" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "fastschema"
      namespace  = var.argocd_namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://k8sforge.github.io/fastschema-chart"
        chart          = "fastschema"
        targetRevision = var.chart_version != null ? var.chart_version : "*"

        helm = {
          values = yamlencode({
            namespace = {
              name   = var.namespace
              create = true
            }
            replicaCount = var.replica_count
            appPort      = 8000
            # Configure FastSchema to run at root path (no prefix needed with dedicated LB)
            appBaseUrl = var.enable_https ? "https://${var.domain_name}" : "http://${var.domain_name}"
            appDashUrl = var.enable_https ? "https://${var.domain_name}/dash" : "http://${var.domain_name}/dash"
            persistence = {
              enabled          = var.persistence_enabled
              size             = var.persistence_size
              storageClassName = var.storage_class_name != "" ? var.storage_class_name : null
            }
            database = var.database_config
            auth     = var.auth_config
            storage  = var.storage_config
            mail     = var.mail_config
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
    kubectl_manifest.fastschema_helm_repo
  ]
}

# Dedicated Ingress for FastSchema - creates its own ALB (no shared group)
# FastSchema runs at root path, so no Nginx proxy or path rewriting is needed
resource "kubectl_manifest" "fastschema_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "fastschema"
      namespace = var.namespace
      annotations = merge(
        {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/dash"
          # NO group.name annotation - this creates a dedicated ALB
        },
        !var.enable_https ? {
          "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
        } : {},
        var.enable_https ? {
          "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
          "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
          "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        } : {},
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
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "fastschema"
                    port = {
                      number = 8000
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

  depends_on = [kubectl_manifest.fastschema_application]
}

data "kubernetes_ingress_v1" "fastschema_server" {
  metadata {
    name      = "fastschema"
    namespace = var.namespace
  }

  depends_on = [kubectl_manifest.fastschema_ingress]
}
