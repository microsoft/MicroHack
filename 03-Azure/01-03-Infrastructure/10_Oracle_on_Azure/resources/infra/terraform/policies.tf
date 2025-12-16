# ===============================================================================
# Azure Policy Definitions and Assignments
# ===============================================================================
# This file defines Azure Policy artifacts to control Oracle Autonomous Database
# deployments across the "mhteams" management group.
# ===============================================================================

data "azurerm_management_group" "mhteams" {
  name = "mhteams"
}

locals {
  oracle_autonomous_database_policy_scope = data.azurerm_management_group.mhteams.id
}

resource "azurerm_policy_definition" "oracle_autonomous_database_restrictions" {
  name                = "oracle-autonomous-database-restrictions"
  display_name        = "Restrict Oracle Autonomous Database Deployment Settings"
  description         = "Ensures Oracle Autonomous Database deployments adhere to mandatory regions and configuration values."
  management_group_id = data.azurerm_management_group.mhteams.id
  policy_type         = "Custom"
  mode                = "All"

  metadata = jsonencode({
    category = "Oracle Database@Azure"
    version  = "1.0.0"
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
          notIn = ["francecentral", "germanywestcentral"]
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
  description          = "Applies the Oracle Autonomous Database deployment restrictions at the management group scope."
  management_group_id  = data.azurerm_management_group.mhteams.id
  policy_definition_id = azurerm_policy_definition.oracle_autonomous_database_restrictions.id
}
