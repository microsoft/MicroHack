# ===============================================================================
# Entra ID Module - Outputs
# ===============================================================================

output "group_object_id" {
  description = "The object ID of the AKS deployment group"
  value       = data.azuread_group.aks_deployment.object_id
}

output "group_display_name" {
  description = "The display name of the AKS deployment group"
  value       = data.azuread_group.aks_deployment.display_name
}

output "group_mail_nickname" {
  description = "The mail nickname of the AKS deployment group"
  value       = data.azuread_group.aks_deployment.mail_nickname
}

output "user_credentials" {
  description = "Initial credentials for the users created for this deployment group"
  value = {
    for key, user in azuread_user.aks_deployment_users :
    key => {
      display_name        = user.display_name
      user_principal_name = user.user_principal_name
      initial_password    = random_password.aks_deployment_users[key].result
    }
  }
  sensitive = true
}

output "user_object_ids" {
  description = "Object IDs for each user created by this module"
  value = {
    for key, user in azuread_user.aks_deployment_users :
    key => user.object_id
  }
}

output "user_principal_names" {
  description = "User principal names for each created user"
  value = {
    for key, user in azuread_user.aks_deployment_users :
    key => user.user_principal_name
  }
}

