# ===============================================================================
# ODAA Module - Variables
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

variable "password" {
  description = "The admin password for the Oracle Autonomous Database"
  type        = string
  sensitive   = true
  default     = null
  validation {
    condition = var.create_autonomous_database ? (
      var.password != null &&
      length(var.password) >= 12 &&
      length(var.password) <= 30
      ) : (
      var.password == null || trimspace(var.password) == ""
    )
    error_message = "Provide an admin password (12-30 characters) when the Oracle Autonomous Database is enabled."
  }
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "create_autonomous_database" {
  description = "Controls whether the Oracle Autonomous Database is provisioned in this deployment."
  type        = bool
  default     = false
}