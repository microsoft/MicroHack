# ===============================================================================
# AKS Module - Variables
# ===============================================================================

variable "prefix" {
  description = "The prefix for resource names"
  type        = string
}

variable "postfix" {
  description = "The postfix for resource names"
  type        = string
  default     = ""
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
}

variable "cidr" {
  description = "The CIDR block for the virtual network"
  type        = string
}

variable "service_cidr" {
  description = "Service CIDR for the AKS cluster"
  type        = string
}

variable "aks_vm_size" {
  description = "The VM size for AKS node pools"
  type        = string
  default     = "Standard_D8ds_v6"
}

variable "os_disk_type" {
  description = "The OS disk type for AKS node pools (Ephemeral or Managed)"
  type        = string
  default     = "Ephemeral"

  validation {
    condition     = contains(["Ephemeral", "Managed"], var.os_disk_type)
    error_message = "os_disk_type must be either 'Ephemeral' or 'Managed'."
  }
}

variable "deployment_user_object_id" {
  description = "The object ID of the Entra ID user that should have deployment access to AKS"
  type        = string
}

variable "subscription_id" {
  description = "The subscription hosting the AKS resources"
  type        = string
}

# ===============================================================================
# DNS Configuration Variables
# ===============================================================================

variable "fqdn_odaa_par" {
  description = "The FQDN for Oracle Database on Autonomous Azure"
  type        = string
  default     = ""
}

variable "fqdn_odaa_app_par" {
  description = "The FQDN for Oracle Database on Autonomous Azure applications"
  type        = string
  default     = ""
}

variable "fqdn_odaa_fra" {
  description = "The FQDN for Oracle Database on Autonomous Azure"
  type        = string
  default     = ""
}

variable "fqdn_odaa_app_fra" {
  description = "The FQDN for Oracle Database on Autonomous Azure applications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}