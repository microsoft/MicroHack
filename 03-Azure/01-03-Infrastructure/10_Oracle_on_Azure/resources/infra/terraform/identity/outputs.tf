# ===============================================================================
# Entra ID User Management - Outputs
# ===============================================================================
# These outputs are used by the main infrastructure Terraform configuration
# to assign RBAC roles to the created users.
# ===============================================================================

output "user_object_ids" {
  description = "Map of username to Azure AD object ID for all created users"
  value       = module.entra_id_users.user_object_ids
}

output "user_principal_names" {
  description = "Map of username to user principal name (UPN) for all created users"
  value       = module.entra_id_users.user_principal_names
}

output "group_object_id" {
  description = "Object ID of the Entra ID group containing all deployment users"
  value       = module.entra_id_users.group_object_id
}

output "user_credentials_file" {
  description = "Path to the JSON file containing user credentials (in terraform root folder)"
  value       = local_file.user_credentials.filename
}

output "user_count" {
  description = "Number of users created"
  value       = var.user_count
}

output "microhack_event_name" {
  description = "Event name used for this deployment"
  value       = var.microhack_event_name
}
