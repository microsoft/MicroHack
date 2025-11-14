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

output "aks_cluster_kube_config_raw" {
  description = "The raw kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
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
    cluster_user_assignment        = azurerm_role_assignment.aks_cluster_user.id
    rbac_writer_assignment         = azurerm_role_assignment.aks_rbac_writer.id
    subscription_reader_assignment = azurerm_role_assignment.subscription_reader.id
    acr_pull_assignment            = azurerm_role_assignment.acr_pull.id
    private_dns_contributor = {
      for key, assignment in azurerm_role_assignment.private_dns_contributor_odaa :
      key => assignment.id
    }
  }
}

# ===============================================================================
# DNS Outputs
# ===============================================================================

output "dns_zones" {
  description = "Information about the private DNS zones created"
  value = {
    zones = {
      for key, zone in azurerm_private_dns_zone.odaa :
      key => {
        id   = zone.id
        name = zone.name
      }
    }

    links = {
      for key, link in azurerm_private_dns_zone_virtual_network_link.odaa :
      key => link.id
    }
  }
}