terraform {
  required_version = ">=1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.19"
    }
  }
}

provider "azurerm" {
  subscription_id = "WILL-BE-REPLACED-BY-SCRIPT"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
  storage_use_azuread = true
}

data "azurerm_client_config" "current" {}