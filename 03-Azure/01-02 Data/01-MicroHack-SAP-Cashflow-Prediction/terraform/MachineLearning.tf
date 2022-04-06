#######################################################################
## Create Application Insights
#######################################################################

resource "azurerm_application_insights" "insights" {
  name                  = "${var.prefix}-insights"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  application_type      = "web"
  tags                  = var.tags
}

#######################################################################
## Create Blob Storage Account
#######################################################################

resource "azurerm_storage_account" "blobaccount" {
  name                      = "sapblob${lower(random_id.id.hex)}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  tags                      = var.tags
}

#######################################################################
## Create Machine Learning Workspace
#######################################################################

resource "azurerm_machine_learning_workspace" "mlws" {
  name                      = "${var.prefix}-ml-ws"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  application_insights_id   = azurerm_application_insights.insights.id
  key_vault_id              = azurerm_key_vault.keyvault.id
  storage_account_id        = azurerm_storage_account.blobaccount.id
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }
}