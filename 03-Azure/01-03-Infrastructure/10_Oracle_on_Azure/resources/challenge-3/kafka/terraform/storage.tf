####################################################
# Storage
####################################################

resource "azurerm_storage_account" "storage" {
  name                     = "${var.prefix}storage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
  # network_rules {
  #   default_action             = "Deny"
  #   virtual_network_subnet_ids = [azurerm_subnet.subnet_aca.id, azurerm_subnet.subnet.id]
  # }
  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_storage_share" "fileshare" {
  name               = var.prefix
  storage_account_id = azurerm_storage_account.storage.id
  # storage_account_name = azurerm_storage_account.storage.name
  quota            = 1
  enabled_protocol = "SMB"
}

# resource "azurerm_storage_share_directory" "fileshare_directory_kafka" {
#   name             = "kafka"
#   storage_share_id = azurerm_storage_share.fileshare.id
# }

# resource "azurerm_storage_share_directory" "fileshare_directory_kafka_plugins" {
#   name             = "plugins"
#   storage_share_id = azurerm_storage_share_directory.fileshare_directory_kafka.id
# }

# resource "azurerm_storage_share_file" "file_spiderman" {
#   name             = "spiderman.txt"
#   storage_share_id = azurerm_storage_share.fileshare.id
#   source           = "files/spiderman.txt"
# }

resource "azurerm_role_assignment" "storage_share_smb_contributor" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azuread_user.current_user_object_id.object_id
}

# resource "azurerm_role_assignment" "storage_share_smb_contributor" {
#   scope                = azurerm_storage_share.fileshare.id
#   role_definition_name = "Storage Account Contributor"
#   principal_id         = data.azuread_user.current_user_object_id.object_id
# }