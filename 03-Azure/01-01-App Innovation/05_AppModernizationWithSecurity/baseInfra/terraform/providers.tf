terraform {
  required_version = "= 1.13.3"

  # Partial configuration: the storage account holding this state is created once by the
  # facilitator bootstrap in docs/Facilitator.md and supplied with
  # `terraform init -backend-config=backend.hcl`. State contains the Windows administrator
  # password, every generated database password, every generated performance API key, and
  # every per-user Entra password, so it must never sit in a local file.
  backend "azurerm" {}

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.6"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.45"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  resource_provider_registrations = "none"

  features {}
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "azuread" {}
