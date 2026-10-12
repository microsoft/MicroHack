locals {
  owner_role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
  role_assignment_ns       = "b24988ac-6180-42a0-ab88-20f7382dd24c" # reuse Owner GUID as stable UUIDv5 namespace
}

resource "azapi_resource" "rg_owner_role_assignment" {
  count     = var.create_role_assignment ? 1 : 0
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5(local.role_assignment_ns, "${var.subscription_id}/${local.rg_name}/${var.assigned_user_object_id}")
  parent_id = azapi_resource.rg.id
  body = {
    properties = {
      roleDefinitionId = local.owner_role_definition_id # Owner
      principalId      = var.assigned_user_object_id
      principalType    = "User"
    }
  }

  lifecycle {
    precondition {
      condition     = !var.create_role_assignment || (var.create_role_assignment && var.assigned_user_object_id != null)
      error_message = "create_role_assignment=true requires non-null assigned_user_object_id"
    }
  }
}

resource "azapi_resource" "vm_identity_owner" {
  for_each = local.stacks

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5(local.role_assignment_ns, "${var.subscription_id}/${local.rg_name}/${azapi_resource.vm[each.key].output.identity.principalId}")
  parent_id = azapi_resource.rg.id
  body = {
    properties = {
      roleDefinitionId = local.owner_role_definition_id # Owner
      principalId      = azapi_resource.vm[each.key].output.identity.principalId
      principalType    = "ServicePrincipal"
    }
  }
  depends_on = [azapi_resource.vm]
}
