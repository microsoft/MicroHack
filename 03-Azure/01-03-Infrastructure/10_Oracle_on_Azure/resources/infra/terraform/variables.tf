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
  default     = "team"
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

variable "fqdn_odaa" {
  description = "The fully qualified domain name (FQDN) for the ODAA deployment"
  type        = string
  default     = "adb.eu-frankfurt-1.oraclecloud.com"
}

variable "fqdn_odaa_app" {
  description = "The fully qualified domain name (FQDN) for ODAA applications"
  type        = string
  default     = "adb.eu-frankfurt-1.oraclecloudapps.com"
}

variable "aks_vm_size" {
  description = "The VM size for AKS nodes"
  type        = string
  default     = "Standard_D4ds_v6"
}

# ===============================================================================
# AKS Deployments Configuration
# ===============================================================================

variable "aks_deployments" {
  description = "List of AKS deployments to create"
  type = list(object({
    subscription_id = string # Azure subscription ID for this AKS deployment
    tenant_id       = string # Azure AD tenant ID for this subscription
  }))

  validation {
    condition     = length(var.aks_deployments) >= 1 && length(var.aks_deployments) <= 5
    error_message = "Define between 1 and 5 AKS deployments."
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

# ===============================================================================
# Entra ID Variables
# ===============================================================================

variable "aks_deployment_group_name" {
  description = "Name of the Entra ID group for AKS deployment access"
  type        = string
  default     = "mhteam"
}

variable "aks_deployment_group_description" {
  description = "Description of the Entra ID group for AKS deployment access"
  type        = string
  default     = "Security group with rights to deploy applications to the Oracle AKS cluster"
}

