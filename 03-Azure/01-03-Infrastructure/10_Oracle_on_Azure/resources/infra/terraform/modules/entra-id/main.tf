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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Get current Azure AD client configuration
data "azuread_client_config" "current" {}

locals {
  user_catalog_entries = jsondecode(file("${path.root}/users.json"))
  user_catalog_by_identifier = {
    for entry in local.user_catalog_entries :
    lower(entry.identifier) => entry
  }

  user_configs = {
    for key, user in var.users :
    key => {
      identifier   = lower(user.identifier)
      catalog_entry = lookup(local.user_catalog_by_identifier, lower(user.identifier), null)
    }
  }

  missing_catalog_identifiers = [
    for cfg in values(local.user_configs) :
    cfg.identifier
    if cfg.catalog_entry == null
  ]

  user_principal_names = {
    for key, cfg in local.user_configs :
    key => (
      cfg.catalog_entry != null && trimspace(coalesce(cfg.catalog_entry.user_principal_name, "")) != ""
      ? cfg.catalog_entry.user_principal_name
      : (
        var.user_principal_domain != null
        ? "${cfg.identifier}@${var.user_principal_domain}"
        : null
      )
    )
  }

  missing_user_principal_names = [
    for key, upn in local.user_principal_names :
    local.user_configs[key].identifier
    if trimspace(coalesce(upn, "")) == ""
  ]

  user_definitions = {
    for key, cfg in local.user_configs :
    key => {
      identifier          = cfg.identifier
      display_name        = cfg.catalog_entry != null ? "${cfg.catalog_entry.given_name} ${cfg.catalog_entry.surname}" : upper(cfg.identifier)
      user_principal_name = local.user_principal_names[key]
      mail_nickname       = cfg.catalog_entry != null ? lower(cfg.catalog_entry.identifier) : cfg.identifier
      given_name          = cfg.catalog_entry != null ? cfg.catalog_entry.given_name : upper(cfg.identifier)
      surname             = cfg.catalog_entry != null ? cfg.catalog_entry.surname : "User"
    }
  }
}

resource "random_password" "aks_deployment_users" {
  for_each = local.user_definitions

  length           = 18
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
}

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

resource "azuread_user" "aks_deployment_users" {
  depends_on = [azuread_group.aks_deployment]
  for_each   = local.user_definitions

  display_name          = each.value.display_name
  user_principal_name   = each.value.user_principal_name
  mail_nickname         = each.value.mail_nickname
  given_name            = each.value.given_name
  surname               = each.value.surname
  password              = random_password.aks_deployment_users[each.key].result
  force_password_change = true
  account_enabled       = true

  lifecycle {
    precondition {
      condition = length(local.missing_catalog_identifiers) == 0 && length(local.missing_user_principal_names) == 0
      error_message = length(local.missing_catalog_identifiers) > 0 ? format("Missing catalog entry for identifiers: %s", join(", ", local.missing_catalog_identifiers)) : format("Missing user_principal_name for identifiers: %s", join(", ", local.missing_user_principal_names))
    }
  }
}

resource "azuread_group_member" "aks_deployment_users" {
  for_each = azuread_user.aks_deployment_users

  group_object_id  = azuread_group.aks_deployment.object_id
  member_object_id = each.value.object_id
}

