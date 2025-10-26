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
  hero_entries = jsondecode(file("${path.module}/hero_names.json"))
  hero_map = {
    for entry in local.hero_entries :
    lower(entry.identifier) => entry
  }

  user_slot_count = 5
  user_slots = [
    for idx in range(local.user_slot_count) : {
      key        = format("%02d", idx)
      identifier = lower("t${var.deployment_index}u${idx + 1}")
      hero       = lookup(local.hero_map, lower("t${var.deployment_index}u${idx + 1}"), null)
    }
  ]

  missing_hero_identifiers = [for slot in local.user_slots : slot.identifier if slot.hero == null]

  missing_user_principal_names = [
    for slot in local.user_slots :
    slot.identifier
    if slot.hero != null && trimspace(coalesce(slot.hero.user_principal_name, "")) == ""
  ]

  user_definitions = {
    for slot in local.user_slots :
    slot.key => {
      display_name         = slot.hero != null ? "${slot.hero.given_name} ${slot.hero.surname}" : upper(slot.identifier)
      user_principal_name  = slot.hero != null ? slot.hero.user_principal_name : null
      mail_nickname        = slot.hero != null ? lower(slot.hero.identifier) : slot.identifier
      given_name           = slot.hero != null ? slot.hero.given_name : upper(slot.identifier)
      surname              = slot.hero != null ? slot.hero.surname : "User"
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

  display_name         = each.value.display_name
  user_principal_name  = each.value.user_principal_name
  mail_nickname        = each.value.mail_nickname
  given_name           = each.value.given_name
  surname              = each.value.surname
  password             = random_password.aks_deployment_users[each.key].result
  force_password_change = true
  account_enabled       = true

  lifecycle {
    precondition {
      condition = length(local.missing_hero_identifiers) == 0 && length(local.missing_user_principal_names) == 0
      error_message = length(local.missing_hero_identifiers) > 0 ? format("Missing hero mapping for identifiers: %s", join(", ", local.missing_hero_identifiers)) : format("Missing user_principal_name for identifiers: %s", join(", ", local.missing_user_principal_names))
    }
  }
}

resource "azuread_group_member" "aks_deployment_users" {
  for_each = azuread_user.aks_deployment_users

  group_object_id  = azuread_group.aks_deployment.object_id
  member_object_id = each.value.object_id
}

