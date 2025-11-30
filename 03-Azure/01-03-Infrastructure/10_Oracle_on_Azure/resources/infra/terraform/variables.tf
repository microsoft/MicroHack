# ===============================================================================
# Variable Definitions for Oracle on Azure Infrastructure
# ===============================================================================

variable "microhack_event_name" {
  description = "Name of the microhack event. Auto-populated from identity/user_credentials.json if not specified."
  type        = string
  default     = null
}

# variable "prefix" {
#   description = "Prefix applied to resource names and user identifiers"
#   type        = string
#   default     = "mh"
# }
# ===============================================================================
# Subscription Variables
# ===============================================================================

variable "odaa_subscription_id" {
  description = "The Azure subscription ID for ODAA resources (single subscription for all ODAA VNets)"
  type        = string
}

variable "location" {
  description = "The location to use for all resources"
  type        = string
  default     = "francecentral"

  validation {
    condition     = contains(["francecentral", "germanywestcentral"], lower(trimspace(var.location)))
    error_message = "location must be either 'francecentral' or 'germanywestcentral'."
  }
}

variable "aks_cidr_base" {
  description = "The base CIDR block for AKS deployments"
  type        = string
  default     = "10.0.0.0"
}

variable "aks_service_cidr" {
  description = "The service CIDR used by all AKS clusters"
  type        = string
  default     = "172.16.0.0/16"
}

variable "odaa_cidr_base" {
  description = "The base CIDR block for ODAA deployments"
  type        = string
  default     = "192.168.0.0"
}

variable "fqdn_odaa_fra" {
  description = "The fully qualified domain name (FQDN) for the ODAA deployment"
  type        = string
  default     = "adb.eu-frankfurt-1.oraclecloud.com"
}

variable "fqdn_odaa_app_fra" {
  description = "The fully qualified domain name (FQDN) for ODAA applications"
  type        = string
  default     = "adb.eu-frankfurt-1.oraclecloudapps.com"
}

variable "fqdn_odaa_app_par" {
  description = "The fully qualified domain name (FQDN) for ODAA applications"
  type        = string
  default     = "adb.eu-paris-1.oraclecloudapps.com"
}

variable "fqdn_odaa_par" {
  description = "The fully qualified domain name (FQDN) for the ODAA deployment"
  type        = string
  default     = "adb.eu-paris-1.oraclecloud.com"
}

variable "enabled_odaa_regions" {
  description = "List of ODAA regions to create Private DNS zones for. Valid values: 'paris', 'frankfurt'"
  type        = list(string)
  default     = ["paris"]

  validation {
    condition     = alltrue([for r in var.enabled_odaa_regions : contains(["paris", "frankfurt"], lower(r))])
    error_message = "enabled_odaa_regions must only contain 'paris' and/or 'frankfurt'."
  }
}

variable "aks_vm_size" {
  description = "The VM size for AKS nodes"
  type        = string
  default     = "Standard_D4as_v5"
}

variable "aks_os_disk_type" {
  description = "OS disk type for AKS node pools (Ephemeral or Managed)"
  type        = string
  default     = "Managed"

  validation {
    condition     = contains(["Ephemeral", "Managed"], var.aks_os_disk_type)
    error_message = "aks_os_disk_type must be either 'Ephemeral' or 'Managed'."
  }
}

variable "oracle_cloud_service_principal_object_id" {
  description = "Object ID of the Oracle Cloud Infrastructure Console enterprise application's service principal."
  type        = string
  default     = "6240ab05-e243-48b2-9619-c3e3f53c6dca"
}

variable "oracle_cloud_service_principal_app_role_value" {
  description = "Optional app role value to assign when granting groups access to the Oracle Cloud service principal. Leave null to use the first available app role."
  type        = string
  default     = null
}

variable "entra_user_principal_domain" {
  description = "Domain suffix for Entra user principal names (used by identity module)"
  type        = string
  default     = "cptazure.org"
}

# ===============================================================================
# AKS Deployments Configuration
# ===============================================================================

variable "user_count" {
  description = "Number of isolated user environments to provision"
  type        = number
  default     = 1

  validation {
    condition     = var.user_count >= 1
    error_message = "At least one user environment must be provisioned."
  }
}

variable "subscription_targets" {
  description = "Ordered list of subscriptions used for round-robin AKS deployment assignment"
  type = list(object({
    subscription_id = string
  }))

  validation {
    condition     = length(var.subscription_targets) >= 1 && length(var.subscription_targets) <= 5
    error_message = "Provide between 1 and 5 subscription targets."
  }
}

# ===============================================================================
# Oracle Database Configuration
# ===============================================================================

variable "create_oracle_database" {
  description = "Controls whether the Oracle Autonomous Database resources are provisioned."
  type        = bool
  default     = false
}

variable "adb_admin_password" {
  description = "The admin password for the Oracle Autonomous Database (shared across all ODAA deployments)"
  type        = string
  sensitive   = true
  default     = null
  validation {
    condition = var.create_oracle_database ? (
      var.adb_admin_password != null &&
      length(var.adb_admin_password) >= 8 &&
      length(var.adb_admin_password) <= 30
      ) : (
      var.adb_admin_password == null || trimspace(var.adb_admin_password) == ""
    )
    error_message = "ADB admin password must be provided (8-30 characters) when the Oracle Autonomous Database is enabled."
  }
}

variable "client_id" {
  description = "The Client ID (Application ID) for the Service Principal. Required for authentication to Azure and Entra ID."
  type        = string

  validation {
    condition     = var.client_id != null && var.client_id != "" && can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.client_id))
    error_message = "The client_id must be a valid GUID/UUID format. Please provide the Service Principal's Application ID."
  }
}

variable "client_secret" {
  description = "The Client Secret for the Service Principal. Required for authentication to Azure and Entra ID."
  type        = string
  sensitive   = true

  validation {
    condition     = var.client_secret != null && var.client_secret != "" && length(var.client_secret) > 0
    error_message = "The client_secret must be provided and cannot be empty. Please provide the Service Principal's client secret."
  }
}

# ===============================================================================
# Tenant Configuration
# ===============================================================================

variable "tenant_id" {
  description = "Azure AD tenant ID for service principal authentication. Used across all subscriptions."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "The tenant_id must be a valid GUID/UUID format."
  }
}

# ===============================================================================
# Identity Configuration
# ===============================================================================

variable "identity_file_path" {
  description = <<-EOT
    Path to the user_credentials.json file generated by the identity/ Terraform
    configuration. This file contains user object IDs, UPNs, group information,
    and passwords.
    
    Defaults to 'user_credentials.json' in the terraform root folder.
    
    Workflow:
      1. Run 'terraform apply' in identity/ folder to create users
      2. Run 'terraform apply' here to deploy infrastructure
  EOT
  type        = string
  default     = "user_credentials.json"
}