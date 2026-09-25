output "registered_providers" {
  description = "List of registered resource provider namespaces"
  value       = [for rp in azurerm_resource_provider_registration.providers : rp.name]
}

output "registration_status" {
  description = "Map of provider names to their registration state"
  value = {
    for key, rp in azurerm_resource_provider_registration.providers :
    rp.name => "Registered"
  }
}
