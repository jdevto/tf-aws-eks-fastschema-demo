output "argocd_username" {
  description = "ArgoCD username"
  value       = module.argocd.argocd_username
}

output "argocd_password" {
  description = "ArgoCD password"
  value       = module.argocd.argocd_password
}

output "fastschema_server_url" {
  description = "FastSchema server URL (dedicated ALB)"
  value       = module.fastschema.fastschema_server_url
}

output "fastschema_dashboard_url" {
  description = "FastSchema dashboard URL (dedicated ALB)"
  value       = module.fastschema.fastschema_dashboard_url
}

# output "platform_url" {
#   description = "Platform URL with protocol (http:// or https://)"
#   value = var.enable_shared_alb ? (
#     var.enable_https ? "https://${module.route53_platform[0].custom_domain}" : "http://${module.route53_platform[0].custom_domain}"
#   ) : ""
# }

# output "shared_alb_dns_name" {
#   description = "Shared ALB DNS name"
#   value       = module.eks.shared_alb_dns_name
# }
