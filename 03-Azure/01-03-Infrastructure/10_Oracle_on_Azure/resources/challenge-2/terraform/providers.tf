terraform {
  required_version = ">=1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.11.0, <4.0"
    }
    # azapi = {
    #   source  = "Azure/azapi"
    #   version = ">=1.8.0"
    # }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

# provider "azapi" {
#   use_oidc = true
# }