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

variable "aks_vm_size" {
  description = "The VM size for AKS node pools"
  type        = string
  default     = "Standard_D8ds_v6"
}

variable "deployment_group_object_id" {
  description = "The object ID of the Entra ID group that should have deployment access to AKS"
  type        = string
}

variable "subscription_id" {
  description = "The subscription hosting the AKS resources"
  type        = string
}

# ===============================================================================
# DNS Configuration Variables
# ===============================================================================

variable "fqdn_odaa" {
  description = "The FQDN for Oracle Database on Autonomous Azure"
  type        = string
  default     = ""
}

variable "fqdn_odaa_app" {
  description = "The FQDN for Oracle Database on Autonomous Azure applications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}