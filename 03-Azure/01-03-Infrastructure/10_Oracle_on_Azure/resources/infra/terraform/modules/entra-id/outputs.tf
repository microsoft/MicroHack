# ===============================================================================
# Entra ID Module - Outputs
# ===============================================================================

output "group_object_id" {
  description = "The object ID of the AKS deployment group"
  value       = azuread_group.aks_deployment.object_id
}

output "group_display_name" {
  description = "The display name of the AKS deployment group"
  value       = azuread_group.aks_deployment.display_name
}

output "group_mail_nickname" {
  description = "The mail nickname of the AKS deployment group"
  value       = azuread_group.aks_deployment.mail_nickname
}

