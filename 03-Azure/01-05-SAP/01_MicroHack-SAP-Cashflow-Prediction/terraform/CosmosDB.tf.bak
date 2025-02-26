#######################################################################
## Create CosmosDB Account
#######################################################################

resource "azurerm_cosmosdb_account" "cosmos" {
  name                      = "${var.prefix}-cosmos-${lower(random_id.id.hex)}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  offer_type                = "Standard"
  kind                      = "GlobalDocumentDB"
  enable_automatic_failover = false

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

#######################################################################
## Create CosmosDB SQL DB
#######################################################################

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "SAP${var.SID}"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = 400
}

#######################################################################
## Create CosmosDB SQL Container
#######################################################################

resource "azurerm_cosmosdb_sql_container" "container" {
  name                  = "paymentData"
  resource_group_name   = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.db.name
  partition_key_path    = "/CustomerNr"
  partition_key_version = 1
  throughput            = 400
}
