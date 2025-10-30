# ===============================================================================
# Variable Definitions for Oracle on Azure Infrastructure
# ===============================================================================

variable "microhack_event_name" {
  type    = string
  default = "mh2025muc"
}
# ===============================================================================
# Subscription Variables
# ===============================================================================

variable "odaa_subscription_id" {
  description = "The Azure subscription ID for ODAA resources (single subscription for all ODAA VNets)"
  type        = string
}

variable "odaa_tenant_id" {
  description = "The Azure AD tenant ID that owns the ODAA subscription"
  type        = string
}

variable "prefix" {
  description = "The prefix to use for all resources"
  type        = string
  default     = "user"
}

variable "location" {
  description = "The location to use for all resources"
  type        = string
  default     = "germanywestcentral"
}

variable "aks_cidr_base" {
  description = "The base CIDR block for AKS deployments"
  type        = string
  default     = "10.0.0.0"
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
  default     = "Standard_D4ds_v6"
}

variable "aks_os_disk_type" {
  description = "OS disk type for AKS node pools (Ephemeral or Managed)"
  type        = string
  default     = "Ephemeral"

  validation {
    condition     = contains(["Ephemeral", "Managed"], var.aks_os_disk_type)
    error_message = "aks_os_disk_type must be either 'Ephemeral' or 'Managed'."
  }
}

variable "entra_user_principal_domain" {
  description = "Optional domain to use for generated Entra ID user principal names. Defaults to the tenant default domain when null."
  type        = string
  default     = null
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

variable "disable_user_credentials_export" {
  description = "Set to true to skip writing the generated user credentials file."
  type        = bool
  default     = false
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
  default     = null # Welcome1234#
  validation {
    condition = var.create_oracle_database ? (
      var.adb_admin_password != null &&
      length(var.adb_admin_password) >= 12 &&
      length(var.adb_admin_password) <= 30
      ) : (
      var.adb_admin_password == null || trimspace(var.adb_admin_password) == ""
    )
    error_message = "ADB admin password must be provided (12-30 characters) when the Oracle Autonomous Database is enabled."
  }
}