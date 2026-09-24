terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3"
    }
  }
}
# Root module configures provider authentication.
