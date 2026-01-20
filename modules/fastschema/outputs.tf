output "fastschema_namespace" {
  value = var.namespace
}

output "fastschema_server_service_name" {
  value = "fastschema"
}

output "fastschema_server_url" {
  description = "FastSchema server URL (dedicated ALB)"
  value = coalesce(
    try(
      length(data.kubernetes_ingress_v1.fastschema_server.status[0].load_balancer[0].ingress) > 0 ? (
        try(
          "${var.enable_https ? "https" : "http"}://${data.kubernetes_ingress_v1.fastschema_server.status[0].load_balancer[0].ingress[0].hostname}",
          "${var.enable_https ? "https" : "http"}://${data.kubernetes_ingress_v1.fastschema_server.status[0].load_balancer[0].ingress[0].ip}"
        )
      ) : null,
      null
    ),
    "ALB URL not in Ingress status yet. Run: aws elbv2 describe-load-balancers --region ${var.aws_region} --query 'LoadBalancers[?contains(LoadBalancerName, `fastschema`)].DNSName' --output text"
  )
}

output "fastschema_dashboard_url" {
  description = "FastSchema dashboard URL (dedicated ALB, root path)"
  value = coalesce(
    try(
      length(data.kubernetes_ingress_v1.fastschema_server.status[0].load_balancer[0].ingress) > 0 ? (
        try(
          "${var.enable_https ? "https" : "http"}://${data.kubernetes_ingress_v1.fastschema_server.status[0].load_balancer[0].ingress[0].hostname}/dash",
          "${var.enable_https ? "https" : "http"}://${data.kubernetes_ingress_v1.fastschema_server.status[0].load_balancer[0].ingress[0].ip}/dash"
        )
      ) : null,
      null
    ),
    "ALB URL not in Ingress status yet. Run: aws elbv2 describe-load-balancers --region ${var.aws_region} --query 'LoadBalancers[?contains(LoadBalancerName, `fastschema`)].DNSName' --output text"
  )
}
