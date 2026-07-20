# ===============================================================================
# Variable Definitions for Oracle on Azure Infrastructure
# ===============================================================================

variable "microhack_event_name" {
  type    = string
  default = "mh2025muc"
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
  default     = "4aecf0e8-2fe2-4187-bc93-0356bd2676f5"
}

variable "odaa_tenant_id" {
  description = "The Azure AD tenant ID that owns the ODAA subscription"
  type        = string
  default     = "f71980b2-590a-4de9-90d5-6fbc867da951"
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

variable "user_credentials_output_path" {
  description = "Path to write a JSON file containing generated user credentials after apply. Defaults to '<repo>/user_credentials.json' when null."
  type        = string
  default     = null
}

variable "entra_user_principal_domain" {
  description = "Optional domain suffix used to construct Entra user principal names when not provided in users.json"
  type        = string
  default     = "cptazure.org"
}

variable "deployment_user_password_length" {
  description = "Length of the generated passwords for deployment users."
  type        = number
  default     = 9

  validation {
    condition     = var.deployment_user_password_length >= 8
    error_message = "Deployment user passwords must be at least 8 characters to satisfy Entra ID complexity requirements."
  }
}

variable "deployment_user_password_include_special" {
  description = "Set to true to include special characters in generated deployment user passwords."
  type        = bool
  default     = false
}

variable "deployment_user_password_special_characters" {
  description = "Special characters to use when deployment_user_password_include_special is true."
  type        = string
  default     = "!#$%&*()-_=+[]{}"
}

variable "deployment_user_password_min_numeric" {
  description = "Minimum numeric characters in the generated deployment user passwords."
  type        = number
  default     = 1

  validation {
    condition     = var.deployment_user_password_min_numeric > 0 || var.deployment_user_password_include_special
    error_message = "Deployment user passwords must include at least one numeric character unless special characters are enabled to meet Entra ID complexity requirements."
  }
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
  description = "Ordered list of subscription/tenant pairs used for round-robin assignment"
  type = list(object({
    subscription_id = string
    tenant_id       = string
  }))
  default = [
    {
      subscription_id = "556f9b63-ebc9-4c7e-8437-9a05aa8cdb25"
      tenant_id       = "f71980b2-590a-4de9-90d5-6fbc867da951"
    },
    {
      subscription_id = "a0844269-41ae-442c-8277-415f1283d422"
      tenant_id       = "f71980b2-590a-4de9-90d5-6fbc867da951"
    },
    {
      subscription_id = "b1658f1f-33e5-4e48-9401-f66ba5e64cce"
      tenant_id       = "f71980b2-590a-4de9-90d5-6fbc867da951"
    },
    {
      subscription_id = "9aa72379-2067-4948-b51c-de59f4005d04"
      tenant_id       = "f71980b2-590a-4de9-90d5-6fbc867da951"
    },
    {
      subscription_id = "98525264-1eb4-493f-983d-16a330caa7f6"
      tenant_id       = "f71980b2-590a-4de9-90d5-6fbc867da951"
    }
  ]

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
# Subscription and Tenant Configuration
# ===============================================================================

variable "subscription_id" {
  description = "The Azure subscription ID where resources will be deployed"
  type        = string
  default     = "4aecf0e8-2fe2-4187-bc93-0356bd2676f5"
}

variable "tenant_id" {
  description = "The Azure AD tenant ID for the subscription"
  type        = string
  default     = "f71980b2-590a-4de9-90d5-6fbc867da951"
}