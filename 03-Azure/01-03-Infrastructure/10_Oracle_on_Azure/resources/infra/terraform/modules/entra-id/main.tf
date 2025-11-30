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
  user_principal_domain = lower(trimspace(coalesce(var.user_principal_domain, "not-set.local")))
  user_catalog_entries  = jsondecode(file("${path.root}/users.json"))

  # Create a map of user configs using index-based lookup instead of identifier
  user_configs = {
    for key, user in var.users :
    key => {
      identifier    = lower(user.identifier)
      index         = tonumber(key)  # Convert string key to number
      catalog_entry = (
        tonumber(key) < length(local.user_catalog_entries) ?
        local.user_catalog_entries[tonumber(key)] :
        null
      )
    }
  }

  # Check if we have enough entries in users.json
  users_json_count = length(local.user_catalog_entries)
  required_count   = length(var.users)

  user_definitions = {
    for key, cfg in local.user_configs :
    key => {
      identifier          = cfg.identifier
      display_name        = cfg.catalog_entry != null ? "${cfg.catalog_entry.given_name} ${cfg.catalog_entry.surname}" : upper(cfg.identifier)
      user_principal_name = format("%s@%s", cfg.identifier, local.user_principal_domain)
      mail_nickname       = cfg.identifier
      given_name          = cfg.catalog_entry != null ? cfg.catalog_entry.given_name : upper(cfg.identifier)
      surname             = cfg.catalog_entry != null ? cfg.catalog_entry.surname : "User"
      employee_id         = cfg.catalog_entry != null ? cfg.catalog_entry.hero_name : null
    }
  }
}

resource "random_password" "aks_deployment_users" {
  for_each = local.user_definitions

  length           = var.user_password_length
  min_upper        = 1
  min_lower        = 1
  min_numeric      = var.user_password_min_numeric
  min_special      = var.user_password_include_special ? 1 : 0
  special          = var.user_password_include_special
  override_special = var.user_password_special_characters

  # Keepers trigger password regeneration when changed
  # Change user_reset_trigger to rotate all passwords
  keepers = {
    reset_trigger = var.user_reset_trigger
    user_id       = each.key
  }

  lifecycle {
    precondition {
      condition     = var.user_password_length >= 8
      error_message = "Entra ID passwords must be at least 8 characters long."
    }

    precondition {
      condition     = var.user_password_min_numeric > 0 || var.user_password_include_special
      error_message = "Entra ID passwords must contain at least three character categories (uppercase, lowercase, numeric or special). Keep numeric characters or enable special characters."
    }
  }
}

# ===============================================================================
# Entra ID Group for AKS Deployment
# ===============================================================================
# This group must already exist in Entra ID. Terraform will only add users to it
# and assign roles to it. The group is not created or managed by Terraform.
# ===============================================================================

data "azuread_group" "aks_deployment" {
  display_name     = var.aks_deployment_group_name
  security_enabled = true
}

resource "azuread_user" "aks_deployment_users" {
  for_each = local.user_definitions

  display_name          = each.value.display_name
  user_principal_name   = each.value.user_principal_name
  mail_nickname         = each.value.mail_nickname
  given_name            = each.value.given_name
  surname               = each.value.surname
  employee_id           = each.value.employee_id
  password              = random_password.aks_deployment_users[each.key].result
  force_password_change = true
  account_enabled       = true

  lifecycle {
    # CRITICAL: After initial creation, never modify the user resource.
    # This prevents Azure AD eventual consistency issues on subsequent applies.
    # Password updates are handled separately via null_resource.update_passwords
    ignore_changes = all

    precondition {
      condition     = local.users_json_count >= local.required_count
      error_message = format("users.json contains %d entries but %d users are being deployed. Please add more entries to users.json.", local.users_json_count, local.required_count)
    }
    precondition {
      condition     = var.user_principal_domain != null && trimspace(var.user_principal_domain) != ""
      error_message = "The user_principal_domain variable must be set to a valid domain."
    }
  }
}

# Wait for Azure AD eventual consistency after user creation (conditionally applied)
# Only created if azuread_propagation_wait_seconds > 0
# GitHub Issue: https://github.com/hashicorp/terraform-provider-azuread/issues/1810
# Community reports show 60-90s delays commonly needed, some environments require 180-300s or up to 48-72 hours
# Azure AD has no SLA for Graph API replication times
resource "time_sleep" "wait_for_user_propagation" {
  count      = var.azuread_propagation_wait_seconds > 0 ? 1 : 0
  depends_on = [azuread_user.aks_deployment_users]

  create_duration = "${var.azuread_propagation_wait_seconds}s"
}

resource "azuread_group_member" "aks_deployment_users" {
  for_each = azuread_user.aks_deployment_users

  group_object_id  = data.azuread_group.aks_deployment.object_id
  member_object_id = each.value.object_id

  depends_on = [
    azuread_user.aks_deployment_users,
    time_sleep.wait_for_user_propagation
  ]

  lifecycle {
    ignore_changes = all
  }
}

# ===============================================================================
# Password Rotation via Azure CLI
# ===============================================================================
# Since azuread_user has ignore_changes = all, we use a null_resource with
# local-exec to update passwords when password_rotation_trigger changes.
# This avoids touching the user resource and prevents race conditions.
# ===============================================================================

resource "null_resource" "update_passwords" {
  for_each = local.user_definitions

  # Trigger when user reset is requested
  triggers = {
    reset_trigger = var.user_reset_trigger
    password_hash = sha256(random_password.aks_deployment_users[each.key].result)
    user_upn      = each.value.user_principal_name
  }

  # Update password via Azure CLI (works with service principal)
  provisioner "local-exec" {
    command     = "az ad user update --id '${each.value.user_principal_name}' --password '${random_password.aks_deployment_users[each.key].result}' --force-change-password-next-sign-in true"
    interpreter = ["pwsh", "-Command"]
    on_failure  = continue  # Don't fail if user doesn't exist yet (first run)
  }

  depends_on = [
    azuread_user.aks_deployment_users,
    azuread_group_member.aks_deployment_users
  ]
}

