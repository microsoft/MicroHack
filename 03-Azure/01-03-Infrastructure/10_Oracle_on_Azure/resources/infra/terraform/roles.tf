# ===============================================================================
# Custom Azure RBAC role definitions
# ===============================================================================

resource "azurerm_role_definition" "oracle_subscriptions_manager_reader" {
  name  = "Oracle Subscriptions Manager Reader"
  scope = "/providers/Microsoft.Management/managementGroups/mhteams"

  description = "Grants reader access to Oracle Database@Azure subscription resources."

  permissions {
    actions = [
      "Oracle.Database/Locations/*/read",
      "Oracle.Database/oracleSubscriptions/*/read",
      "Oracle.Database/oracleSubscriptions/listCloudAccountDetails/action"
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/providers/Microsoft.Management/managementGroups/mhteams",
    "/subscriptions/${data.azurerm_subscription.odaa.subscription_id}"
  ]
}
