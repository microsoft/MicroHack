# ===============================================================================
# Entra ID Module - Main Configuration
# ===============================================================================
# This module creates an Entra ID security group for AKS deployment access
# and assigns appropriate RBAC roles for Kubernetes deployment operations.
# ===============================================================================

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Get current Azure AD client configuration
data "azuread_client_config" "current" {}

# ===============================================================================
# Entra ID Group for AKS Deployment
# ===============================================================================

resource "azuread_group" "aks_deployment" {
  display_name     = var.aks_deployment_group_name
  description      = var.aks_deployment_group_description
  security_enabled = true
  mail_enabled     = false

  # Generate a unique mail nickname based on the display name
  mail_nickname = lower(replace("${var.aks_deployment_group_name}-${lookup(var.tags, "AKSDeployment", "aks")}", "/[^a-zA-Z0-9]/", ""))

  # Group owners (optional - can be managed separately)
  owners = [data.azuread_client_config.current.object_id]

  # Group behavior settings (only supported for unified groups, omitted for security groups)
}

