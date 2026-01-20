variable "enable" {
  description = "Enable/disable the Bitwarden Reader module"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Namespace for the reader demo app"
  type        = string
  default     = "bitwarden-secrets"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "bitwarden-reader"
}

variable "image" {
  description = "Container image for the reader app"
  type        = string
  default     = "ghcr.io/platformfuzz/k8s-bitwarden-reader:latest"
}

variable "image_pull_policy" {
  description = "Image pull policy"
  type        = string
  default     = "IfNotPresent"
}

variable "secret_names" {
  description = "List of Kubernetes secret names to read and display"
  type        = list(string)
  default     = ["example-secret"]
}

variable "chart_version" {
  description = "Version of the bitwarden-reader Helm chart. If null, uses latest."
  type        = string
  default     = null
}

variable "argocd_namespace" {
  description = "Namespace where ArgoCD is installed (used for registering the Helm repo and creating Application)"
  type        = string
  default     = "argocd"
}

variable "shared_alb_ingress_group_name" {
  description = "Name of the shared ALB ingress group (for shared ALB configuration)"
  type        = string
  default     = ""
}

variable "shared_alb_security_group_id" {
  description = "Security group ID for the shared ALB (for IP restrictions)"
  type        = string
  default     = ""
}

variable "path_prefix" {
  description = "Path prefix for the reader app on the shared ALB (e.g., /reader)"
  type        = string
  default     = "/reader"
}

variable "subnet_ids" {
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
  type        = list(string)
  default     = []
}

variable "enable_https" {
  description = "Enable HTTPS for ingress using ACM certificate"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Required when enable_https is true."
  type        = string
  default     = ""
}

variable "ssl_redirect" {
  description = "Redirect HTTP to HTTPS when enable_https is true"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
