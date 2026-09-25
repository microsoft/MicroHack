output "resource_group_names" {
  description = "List of provisioned resource group names."
  value       = [for k, m in module.user_environment : m.resource_group_name]
}

output "dotnet_vm_names" {
  description = "List of provisioned .NET/SQL Server VM names."
  value       = [for _, environment in module.user_environment : environment.dotnet_vm_name]
}

output "java_vm_names" {
  description = "List of provisioned Java/PostgreSQL VM names."
  value       = [for _, environment in module.user_environment : environment.java_vm_name]
}

output "legacy_vm_access_by_environment" {
  description = "Map of participant index to each legacy VM's RDP address and the app URL to open inside it."
  value = {
    for index, environment in module.user_environment :
    index => environment.legacy_vm_access
  }
}

output "public_ip_addresses_by_environment" {
  description = "Map of participant index to the public IP address of each legacy VM, used for RDP."
  value = {
    for index, environment in module.user_environment :
    index => environment.public_ip_addresses
  }
}

output "vm_names_by_environment" {
  description = "Map of participant index to unambiguous dotnet and java VM names."
  value = {
    for index, environment in module.user_environment :
    index => environment.vm_names
  }
}

output "private_ip_addresses_by_environment" {
  description = "Map of participant index to the distinct dotnet and java private IP addresses."
  value = {
    for index, environment in module.user_environment :
    index => environment.private_ip_addresses
  }
}

output "vnet_names" {
  description = "List of provisioned VNet names."
  value       = [for k, m in module.user_environment : m.vnet_name]
}

output "entra_user_principal_names" {
  description = "List of Entra user principal names (when manage_entra_users=true)."
  value       = var.manage_entra_users ? [for k, u in module.entra_users : u.user_principal_name] : []
}

output "entra_user_object_ids" {
  description = "List of Entra user object ids (when manage_entra_users=true)."
  value       = var.manage_entra_users ? [for k, u in module.entra_users : u.object_id] : []
}

output "entra_user_credentials" {
  description = <<EOT
Per-participant sign-in credentials keyed by user index. Each participant has a distinct
password that must be changed at first sign-in. Read one entry at a time
(`terraform output -json entra_user_credentials`) and hand each entry to exactly one person.
EOT
  sensitive   = true
  value = var.manage_entra_users ? {
    for index, user in module.entra_users : index => {
      user_principal_name = user.user_principal_name
      initial_password    = user.password
    }
  } : {}
}

output "performance_api_keys" {
  description = <<EOT
Per-participant, per-stack performance-test API key, keyed by user index. Terraform generates
it, the provisioner writes it into `C:\protected\*.json`, and participants surface it to
the container app as `PERFTEST_API_KEY`. Challenge 2's load test reads the key from a Key Vault
secret in a separate deployment, so that secret must carry this same value for the run to
authenticate.
EOT
  sensitive   = true
  value = {
    for index, environment in module.user_environment :
    index => environment.performance_api_keys
  }
}

output "region_assignment" {
  description = "Map of user index -> region (round-robin assignment)."
  value       = { for i in local.user_indices : i => local.user_location_map[i] }
}

output "region_distribution" {
  description = "Count of environments per region."
  value       = { for r in var.locations : r => length([for i in local.user_indices : local.user_location_map[i] if local.user_location_map[i] == r]) }
}

output "registered_resource_providers" {
  description = "List of registered Azure resource providers."
  value       = var.manage_sub_providers ? module.resource_providers[0].registered_providers : []
}

output "deployment_footprint" {
  description = "Calculated doubled VM, vCPU, OS-disk count, and OS-disk GiB footprint."
  value       = local.deployment_footprint
}

output "defender_pricing_resource_ids" {
  description = "Map of enabled frozen Defender pricing names to subscription resource IDs."
  value       = { for name, pricing in azapi_resource.defender_pricing : name => pricing.id }
}

output "defender_budget_resource_id" {
  description = "Subscription budget resource ID when the Defender foundation is enabled."
  value       = try(azapi_resource.defender_budget[0].id, null)
}

output "participant_security_reader_assignment_ids" {
  description = "Map of participant indices to assigned-resource-group Security Reader role assignment IDs."
  value       = { for index, assignment in azapi_resource.participant_security_reader : index => assignment.id }
}
