output "user_principal_name" { value = azuread_user.this.user_principal_name }
output "object_id" { value = azuread_user.this.object_id }
output "display_name" { value = azuread_user.this.display_name }

output "password" {
  description = "Initial password for this single user; must be changed at first sign-in."
  value       = random_password.this.result
  sensitive   = true
}
