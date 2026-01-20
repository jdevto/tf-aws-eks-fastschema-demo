# Bitwarden Reader Module

A Terraform module that deploys the [bitwarden-reader Helm chart](https://k8sforge.github.io/bitwarden-reader-chart/) via ArgoCD to demonstrate reading secrets synced from Bitwarden Secrets Manager to Kubernetes.

## Overview

This module deploys the [bitwarden-reader Helm chart](https://k8sforge.github.io/bitwarden-reader-chart/) via ArgoCD as a GitOps-managed application that:

- Reads Kubernetes secrets synced by the Bitwarden Secrets Manager Operator
- Displays secrets in a user-friendly web interface
- Shows sync status and metadata from BitwardenSecret CRDs
- Provides REST API endpoints for programmatic access
- Uses shared ALB for ingress (if configured)

**Helm Chart**: [bitwarden-reader](https://k8sforge.github.io/bitwarden-reader-chart/)
**Container Image**: `ghcr.io/platformfuzz/k8s-bitwarden-reader:latest`
**Deployment**: Via ArgoCD (GitOps)

## Features

- **GitOps Deployment**: Managed via ArgoCD Application
- **Helm Chart**: Uses the official bitwarden-reader Helm chart
- **Web UI**: Beautiful, responsive interface to view synced secrets
- **API Endpoints**: REST API for programmatic access
- **RBAC**: Proper Kubernetes RBAC for reading secrets and BitwardenSecret CRDs
- **Health Checks**: Liveness and readiness probes
- **Shared ALB**: Integrates with shared ALB for ingress
- **Single Replica**: No HA needed (single instance)

## Usage

```hcl
module "bitwarden_reader" {
  source = "./modules/bitwarden-reader"

  namespace     = "bitwarden-secrets"
  secret_names  = ["example-secret", "example-secret2"]
  path_prefix   = "/reader"

  # Shared ALB configuration
  shared_alb_ingress_group_name = module.eks.shared_alb_ingress_group_name
  shared_alb_security_group_id  = module.eks.shared_alb_security_group_id
  subnet_ids                    = module.vpc.public_subnet_ids

  # HTTPS configuration (optional)
  enable_https   = true
  certificate_arn = var.certificate_arn
  ssl_redirect   = true

  # ArgoCD configuration
  argocd_namespace = module.argocd.argocd_namespace

  tags = local.common_tags

  depends_on = [
    module.bitwarden,
    module.argocd
  ]
}
```

## Architecture

```
Bitwarden Secrets Manager
         ↓
Bitwarden Operator (syncs)
         ↓
Kubernetes Secret (example-secret)
         ↓
Bitwarden Reader App (reads & displays)
         ↓
Shared ALB (ingress)
```

## Endpoints

When deployed with `path_prefix = "/reader"`:

- `/reader` - Main web interface
- `/reader/api/v1/secrets` - JSON API for secrets
- `/reader/api/v1/health` - Health check endpoint

## Requirements

- Bitwarden Secrets Manager Operator installed (via `bitwarden` module)
- ArgoCD installed and configured
- BitwardenSecret CRD configured
- Secrets synced to the target namespace
- RBAC permissions to read secrets
- Shared ALB configured (if using shared ALB ingress)

## Variables

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| enable | Enable/disable the module | `bool` | `true` | no |
| namespace | Namespace for the reader app | `string` | `"bitwarden-secrets"` | no |
| app_name | Name of the application | `string` | `"bitwarden-reader"` | no |
| secret_names | List of Kubernetes secret names to read | `list(string)` | `["example-secret"]` | no |
| path_prefix | Path prefix on shared ALB | `string` | `"/reader"` | no |
| shared_alb_ingress_group_name | Shared ALB ingress group name | `string` | `""` | no |
| shared_alb_security_group_id | Shared ALB security group ID | `string` | `""` | no |
| argocd_namespace | ArgoCD namespace | `string` | `"argocd"` | no |
| chart_version | Helm chart version | `string` | `null` | no |

See `variables.tf` for all available configuration options.

## Outputs

- `alb_hostname` - ALB hostname (if shared ALB enabled)
- `namespace` - Namespace where app is deployed
- `service_name` - Kubernetes service name
- `path_prefix` - Path prefix for accessing the app
