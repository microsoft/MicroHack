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

# ===============================================================================
# Policy: Restrict Oracle ADB Properties via Tags
# ===============================================================================
# Since Oracle.Database provider doesn't expose field aliases yet, we use a
# tag-based approach to enforce restrictions. Users must tag their ADBs with
# approved values, and policy denies non-compliant tags.
#
# Required tags:
# - adb-compute-model: Must be "ecpu"
# - adb-max-ecpus: Must be "2" or "4" (enforces ≤4)
# - adb-auto-scaling: Must be "disabled"

resource "azurerm_policy_definition" "restrict_adb_properties" {
  name                = "restrict-adb-properties"
  display_name        = "Restrict Oracle Autonomous Database Properties via Tags"
  description         = "Enforces ADB property restrictions using tags. Required tags: adb-compute-model=ecpu, adb-max-ecpus (2 or 4), adb-auto-scaling=disabled."
  management_group_id = data.azurerm_management_group.mhteams.id
  policy_type         = "Custom"
  mode                = "All"

  metadata = jsonencode({
    category = "Oracle Database@Azure"
    version  = "2.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Oracle.Database/autonomousDatabases"
        },
        {
          anyOf = [
            # Require adb-compute-model tag
            {
              field  = "tags['adb-compute-model']"
              exists = false
            },
            # Deny if compute model is not ECPU
            {
              field     = "tags['adb-compute-model']"
              notEquals = "ecpu"
            },
            # Require adb-max-ecpus tag
            {
              field  = "tags['adb-max-ecpus']"
              exists = false
            },
            # Deny if max ECPUs exceeds 4
            {
              field = "tags['adb-max-ecpus']"
              notIn = ["2", "4"]
            },
            # Require adb-auto-scaling tag
            {
              field  = "tags['adb-auto-scaling']"
              exists = false
            },
            # Deny if auto-scaling is enabled
            {
              field     = "tags['adb-auto-scaling']"
              notEquals = "disabled"
            }
          ]
        }
      ]
    }
    then = {
      effect = "Deny"
    }
  })
}

resource "azurerm_management_group_policy_assignment" "restrict_adb_properties" {
  name                 = "restrict-adb-props"
  display_name         = azurerm_policy_definition.restrict_adb_properties.display_name
  description          = "Enforces ADB property restrictions via tags: compute-model=ecpu, max-ecpus≤4, auto-scaling=disabled."
  management_group_id  = data.azurerm_management_group.mhteams.id
  policy_definition_id = azurerm_policy_definition.restrict_adb_properties.id
}
