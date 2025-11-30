# ===============================================================================
# Azure Policy Definitions and Assignments
# ===============================================================================
# This file defines Azure Policy artifacts to control Oracle Autonomous Database
# deployments across the "mhteams" management group.
#
# Current restriction: Location only (francecentral, germanywestcentral)
# ===============================================================================

data "azurerm_management_group" "mhteams" {
  name = "mhteams"
}

locals {
  oracle_autonomous_database_policy_scope = data.azurerm_management_group.mhteams.id
}

resource "azurerm_policy_definition" "oracle_autonomous_database_restrictions" {
  name                = "oracle-autonomous-database-restrictions"
  display_name        = "Restrict Oracle Autonomous Database to Allowed Regions"
  description         = "Ensures Oracle Autonomous Database deployments are only allowed in francecentral region."
  management_group_id = data.azurerm_management_group.mhteams.id
  policy_type         = "Custom"
  mode                = "All"

  metadata = jsonencode({
    category = "Oracle Database@Azure"
    version  = "1.2.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Oracle.Database/autonomousDatabases"
        },
        {
          field = "location"
          notIn = ["francecentral"]
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "oracle_autonomous_database_restrictions" {
  name                 = "odaa-adb-constraints"
  display_name         = azurerm_policy_definition.oracle_autonomous_database_restrictions.display_name
  description          = "Restricts Oracle Autonomous Database deployments to francecentral and germanywestcentral regions only."
  management_group_id  = data.azurerm_management_group.mhteams.id
  policy_definition_id = azurerm_policy_definition.oracle_autonomous_database_restrictions.id
}
