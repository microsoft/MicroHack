#########################################################################################
#                                                                                       #
#  JIT Access Policy                                                                    #
#                                                                                       #
#########################################################################################
data "azurerm_virtual_machine" "oracle_primary_vm" {
  name                = module.vm_primary.vm.name
  resource_group_name = module.common_infrastructure.resource_group.name

  depends_on = [module.vm_primary,
    module.storage_primary
  ]
}

data "azurerm_virtual_machine" "oracle_secondary_vm" {
  name                = module.vm_secondary.vm.name
  resource_group_name = module.common_infrastructure.resource_group.name

  depends_on = [module.vm_secondary
    , module.storage_secondary
  ]
}

resource "time_sleep" "wait_for_primary_vm_creation" {
  create_duration = var.jit_wait_for_vm_creation

  depends_on = [data.azurerm_virtual_machine.oracle_primary_vm,
    module.storage_primary
  ]
}

resource "time_sleep" "wait_for_secondary_vm_creation" {
  create_duration = var.jit_wait_for_vm_creation

  depends_on = [data.azurerm_virtual_machine.oracle_secondary_vm
    , module.storage_secondary
  ]
}


resource "azapi_resource" "jit_ssh_policy_primary" {
  count                     = module.vm_primary.database_server_count
  name                      = "JIT-SSH-Policy-primary"
  parent_id                 = "${module.common_infrastructure.resource_group.id}/providers/Microsoft.Security/locations/${module.common_infrastructure.resource_group.location}"
  type                      = "Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01"
  schema_validation_enabled = false
  body = jsonencode({
    "kind" : "Basic"
    "properties" : {
      "virtualMachines" : [{
        "id" : "/subscriptions/${module.common_infrastructure.current_subscription.subscription_id}/resourceGroups/${module.common_infrastructure.resource_group.name}/providers/Microsoft.Compute/virtualMachines/${module.vm_primary.vm.name}",
        "ports" : [
          {
            "number" : 22,
            "protocol" : "TCP",
            "allowedSourceAddressPrefix" : "*",
            "maxRequestAccessDuration" : "PT3H"
          }
        ]
      }]
    }
  })

  depends_on = [time_sleep.wait_for_primary_vm_creation]
}

resource "azapi_resource" "jit_ssh_policy_secondary" {
  count                     = module.vm_secondary.database_server_count
  name                      = "JIT-SSH-Policy-secondary"
  parent_id                 = "${module.common_infrastructure.resource_group.id}/providers/Microsoft.Security/locations/${module.common_infrastructure.resource_group.location}"
  type                      = "Microsoft.Security/locations/jitNetworkAccessPolicies@2020-01-01"
  schema_validation_enabled = false
  body = jsonencode({
    "kind" : "Basic"
    "properties" : {
      "virtualMachines" : [{
        "id" : "/subscriptions/${module.common_infrastructure.current_subscription.subscription_id}/resourceGroups/${module.common_infrastructure.resource_group.name}/providers/Microsoft.Compute/virtualMachines/${module.vm_secondary.vm.name}",
        "ports" : [
          {
            "number" : 22,
            "protocol" : "TCP",
            "allowedSourceAddressPrefix" : "*",
            "maxRequestAccessDuration" : "PT3H"
          }
        ]
      }]
    }
  })

  depends_on = [time_sleep.wait_for_secondary_vm_creation]
}
