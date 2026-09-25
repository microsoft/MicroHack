output "resource_group_name" { value = local.rg_name }
output "resource_group_id" { value = azapi_resource.rg.id }
output "vnet_name" { value = local.vnet_name }

output "dotnet_vm_name" { value = local.stacks.dotnet.vm_name }
output "java_vm_name" { value = local.stacks.java.vm_name }

output "vm_names" {
  value = { for stack, config in local.stacks : stack => config.vm_name }
}

output "private_ip_addresses" {
  value = {
    for stack, nic in azapi_resource.nic :
    stack => nic.output.properties.ipConfigurations[0].properties.privateIPAddress
  }
}

output "public_ip_addresses" {
  description = "Public IP address of each legacy VM. Used for RDP; the app itself is browsed at localhost inside the VM."
  value = {
    for stack, pip in azapi_resource.vm_public_ip :
    stack => pip.output.properties.ipAddress
  }
}

# The legacy app is only reachable from the VM it runs on, so the useful thing to hand a
# participant is the RDP address plus the URL to type once they are inside.
output "legacy_vm_access" {
  description = "Per stack: the RDP address of the legacy VM and the URL to open in a browser inside it."
  value = {
    for stack, config in local.stacks : stack => {
      rdp_address       = azapi_resource.vm_public_ip[stack].output.properties.ipAddress
      app_url_inside_vm = "http://localhost:${config.app_port}"
    }
  }
}

# The same value has to reach two places that are deployed separately: the container app,
# via the protected parameter files, and the Key Vault secret Challenge 2's load test reads.
# Exposing it is what lets the facilitator make the second one match the first.
output "performance_api_keys" {
  description = "Per-stack performance-test API key, surfaced to the container app as PERFTEST_API_KEY."
  sensitive   = true
  value       = { for stack, secret in random_password.performance_api_key : stack => secret.result }
}
