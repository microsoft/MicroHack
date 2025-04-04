terraform {
  required_version = ">=1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.19"
    }
  }
}

provider "azurerm" {
  #skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
  subscription_id = "971650f0-3120-4775-a049-67192bff7e56"
}