output "release_name" {
  description = "Name of the ingress-nginx Helm release"
  value       = helm_release.this.name
}

output "namespace" {
  description = "Namespace where ingress-nginx is installed"
  value       = var.namespace
}

output "service_annotations" {
  description = "Annotations applied to the ingress controller Service"
  value       = var.controller_service_annotations
}

output "controller_service_ip" {
  description = "External IP assigned to the ingress controller Service"
  value       = try(data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].ip, null)
}
