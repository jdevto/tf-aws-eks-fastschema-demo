output "alb_hostname" {
  description = "ALB hostname for the reader app"
  value       = var.enable && var.shared_alb_ingress_group_name != "" ? try(data.kubernetes_ingress_v1.reader[0].status[0].load_balancer[0].ingress[0].hostname, null) : null
}

output "namespace" {
  description = "Namespace where the reader app is deployed"
  value       = var.enable ? var.namespace : null
}

output "service_name" {
  description = "Service name for the reader app"
  value       = var.enable ? var.app_name : null
}

output "path_prefix" {
  description = "Path prefix for accessing the reader app"
  value       = var.path_prefix
}
