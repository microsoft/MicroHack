# ===============================================================================
# AKS Module - Outputs
# ===============================================================================

output "aks_cluster_id" {
  description = "The ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_cluster_private_fqdn" {
  description = "The private FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.private_fqdn
}

output "aks_cluster_kube_config" {
  description = "The Kubernetes configuration for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.aks.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.aks.id
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.aks.id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.aks.name
}

output "subnet_id" {
  description = "The ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks.id
}

output "aks_identity_principal_id" {
  description = "The principal ID of the AKS cluster managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "aks_identity_tenant_id" {
  description = "The tenant ID of the AKS cluster managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
}

output "rbac_assignments" {
  description = "Information about RBAC role assignments"
  value = {
    cluster_user_assignment = azurerm_role_assignment.aks_cluster_user.id
    rbac_admin_assignment   = azurerm_role_assignment.aks_rbac_admin.id
    contributor_assignment  = azurerm_role_assignment.aks_contributor.id
    network_assignment      = azurerm_role_assignment.network_contributor.id
  }
}

# ===============================================================================
# DNS Outputs
# ===============================================================================

output "dns_zones" {
  description = "Information about the private DNS zones created"
  value = {
    odaa_zone_id       = azurerm_private_dns_zone.odaa.id
    odaa_zone_name     = azurerm_private_dns_zone.odaa.name
    odaa_app_zone_id   = azurerm_private_dns_zone.odaa_app.id
    odaa_app_zone_name = azurerm_private_dns_zone.odaa_app.name
  }
}