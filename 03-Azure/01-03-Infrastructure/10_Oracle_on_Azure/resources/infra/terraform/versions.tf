# ===============================================================================
# Terraform Versions Configuration
# ===============================================================================
# This file defines the required Terraform version and provider constraints
# for the Oracle on Azure infrastructure deployment.
# ===============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  # Uncomment and configure the backend for remote state storage
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "saterraformstate"
  #   container_name       = "tfstate"
  #   key                  = "oracle-on-azure.tfstate"
  # }
}