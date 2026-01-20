variable "namespace" {
  type    = string
  default = "fastschema"
}

variable "chart_version" {
  type        = string
  default     = "0.1.3"
  description = "Version of the k8sforge/fastschema-chart Helm chart. If null, uses latest."
}

variable "argocd_namespace" {
  type        = string
  default     = "argocd"
  description = "Namespace where ArgoCD is installed (used for registering the Helm repo and creating Application)"
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for ALB (should be public subnets for internet-facing ALB)"
}

variable "enable_https" {
  type        = bool
  default     = false
  description = "Enable HTTPS for FastSchema ingress using ACM certificate. If true, requires certificate_arn."
}

variable "ssl_redirect" {
  type        = bool
  default     = true
  description = "Redirect HTTP to HTTPS when enable_https is true. If false, both HTTP and HTTPS are accessible."
}

variable "certificate_arn" {
  type        = string
  default     = ""
  description = "ACM certificate ARN for HTTPS. Required when enable_https is true."
}

variable "domain_name" {
  type        = string
  description = "Domain name for FastSchema (e.g., fastschema.dev.geonet.cloud). Used to construct the full URL."
}

variable "replica_count" {
  type        = number
  default     = 1
  description = "Number of FastSchema replicas"
}

variable "persistence_enabled" {
  type        = bool
  default     = true
  description = "Enable persistent volume for FastSchema data. Set to false to disable persistence (useful for testing or if using external storage)."
}

variable "persistence_size" {
  type        = string
  default     = "10Gi"
  description = "Size of the persistent volume for FastSchema data"
}

variable "storage_class_name" {
  type        = string
  default     = ""
  description = "Storage class name for persistent volume. Empty string uses cluster default storage class (e.g., 'gp3' if EBS CSI driver is enabled)."
}

variable "database_config" {
  type = object({
    driver                    = optional(string, "sqlite")
    name                      = optional(string, "")
    host                      = optional(string, "localhost")
    port                      = optional(string, "")
    user                      = optional(string, "")
    password                  = optional(string, "")
    existingSecret            = optional(string, "")
    existingSecretPasswordKey = optional(string, "password")
    disableForeignKeys        = optional(bool, false)
  })
  default = {
    driver = "sqlite"
  }
  description = "Database configuration for FastSchema"
}

variable "auth_config" {
  type = object({
    enabled          = optional(bool, false)
    enabledProviders = optional(list(string), ["local"])
    providers        = optional(map(any), {})
  })
  default = {
    enabled          = false
    enabledProviders = ["local"]
    providers        = {}
  }
  description = "Auth configuration for FastSchema"
}

variable "storage_config" {
  type = object({
    defaultDisk = optional(string, "public")
    disks       = optional(list(any), [])
  })
  default = {
    defaultDisk = "public"
    disks = [
      {
        name        = "public"
        driver      = "local"
        root        = "./public"
        public_path = "/files"
        base_url    = "http://localhost:8000/files"
      }
    ]
  }
  description = "Storage configuration for FastSchema"
}

variable "mail_config" {
  type = object({
    senderName    = optional(string, "")
    senderMail    = optional(string, "")
    defaultClient = optional(string, "")
    clients       = optional(list(any), [])
  })
  default = {
    senderName    = ""
    senderMail    = ""
    defaultClient = ""
    clients       = []
  }
  description = "Mail configuration for FastSchema"
}
