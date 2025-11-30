# ===============================================================================
# Entra ID User Management - Provider Configuration
# ===============================================================================

provider "azuread" {
  tenant_id     = var.tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}
