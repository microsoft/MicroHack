# ===============================================================================
# Entra ID User Management - Variable Definitions
# ===============================================================================

variable "microhack_event_name" {
  description = "Name of the microhack event, used for resource tagging"
  type        = string
  default     = "mh2025muc"
}

variable "user_count" {
  description = "Number of isolated user environments to provision"
  type        = number
  default     = 1

  validation {
    condition     = var.user_count >= 1
    error_message = "At least one user environment must be provisioned."
  }
}

variable "tenant_id" {
  description = "Azure AD tenant ID for service principal authentication"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "The tenant_id must be a valid GUID/UUID format."
  }
}

variable "client_id" {
  description = "The Client ID (Application ID) for the Service Principal"
  type        = string

  validation {
    condition     = var.client_id != null && var.client_id != "" && can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.client_id))
    error_message = "The client_id must be a valid GUID/UUID format."
  }
}

variable "client_secret" {
  description = "The Client Secret for the Service Principal"
  type        = string
  sensitive   = true

  validation {
    condition     = var.client_secret != null && var.client_secret != "" && length(var.client_secret) > 0
    error_message = "The client_secret must be provided and cannot be empty."
  }
}

variable "entra_user_principal_domain" {
  description = "Domain suffix used to construct Entra user principal names"
  type        = string
  default     = "cptazure.org"
}

# ===============================================================================
# Azure AD Workarounds
# ===============================================================================

variable "azuread_propagation_wait_seconds" {
  description = <<-EOT
    Wait time in seconds for Azure AD changes to propagate before adding group membership.
    Set to 0 to disable wait.
    
    WORKAROUND: Azure AD has eventual consistency issues with group membership operations.
    GitHub Issue: https://github.com/hashicorp/terraform-provider-azuread/issues/1810
    
    Recommended values:
    - Small tenants: 90-180 seconds
    - Medium tenants: 180-300 seconds
    - Large tenants (5000+ users): Up to 48-72 hours reported
    
    Since users are in a separate Terraform run, you can use a lower value (60-90s)
    because the infrastructure deployment will occur later anyway.
  EOT
  type        = number
  default     = 90

  validation {
    condition     = var.azuread_propagation_wait_seconds >= 0
    error_message = "azuread_propagation_wait_seconds must be 0 or greater."
  }
}

variable "user_reset_trigger" {
  description = <<-EOT
    Change this value to reset ALL users for the next workshop event.
    This performs TWO operations:
    1. Rotates passwords - generates new random passwords for all users
    2. Resets MFA - removes all registered MFA methods (authenticator apps, phone, etc.)
    
    Set to "disabled" to skip both operations.
    
    Examples:
    - Use a date: "2025-11-29" (reset before each event)
    - Use an event name: "workshop-december-2025"
    - Use "disabled" to skip reset
    
    Workflow:
    1. After event ends: change to "post-event-X" and apply (revokes access)
    2. Before next event: change to "event-Y" and apply (new credentials)
    3. Distribute new user_credentials.json to participants
    4. Attendees register their own MFA on first Azure login
    
    IMPORTANT for MFA reset: Requires UserAuthenticationMethod.ReadWrite.All
    permission on service principal, OR run scripts/reset-user-mfa.ps1 manually
    as Authentication Administrator.
  EOT
  type        = string
  default     = "disabled"
}
