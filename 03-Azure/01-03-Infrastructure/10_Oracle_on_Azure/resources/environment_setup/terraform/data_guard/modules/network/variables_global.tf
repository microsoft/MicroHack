variable "resource_group" {
  type = object({
    name     = string
    location = string
    id       = string
  })
  description = "Details of the resource group"
  default     = null
}

variable "diagnostic_target" {
  type        = string
  description = "The destination type of the diagnostic settings"
  default     = "Log_Analytics_Workspace"
  validation {
    condition     = contains(["Log_Analytics_Workspace", "Storage_Account", "Event_Hubs", "Partner_Solutions"], var.diagnostic_target)
    error_message = "Allowed values are Log_Analytics_Workspace, Storage_Account, Event_Hubs, Partner_Solutions"
  }
}

variable "storage_account_id" {
  description = "Storage account ID used for diagnostics"
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
  default     = null
}

variable "eventhub_authorization_rule_id" {
  description = "ID of an Event Hub authorization rule"
  type        = string
  default     = null
}

variable "partner_solution_id" {
  type        = string
  description = "Value of the partner solution ID"
  default     = null
}

variable "is_diagnostic_settings_enabled" {
  type        = bool
  description = "Whether diagnostic settings are enabled"
  default     = false
}

variable "role_assignments_pip" {
  type = map(object({
    name = string
  }))
  description = "Role assignments scoped to the public IP address"
}

variable "role_assignments_nsg" {
  type = map(object({
    name = string
  }))
  description = "Role assignments scoped to the network security group"
  default     = {}
}

variable "role_assignments_vnet" {
  type = map(object({
    name = string
  }))
  description = "Role assignments scoped to the virtual network"
  default     = {}
}

variable "role_assignments_subnet" {
  type = map(object({
    name = string
  }))
  description = "Role assignments scoped to the subnet"
  default     = {}
}

variable "nsg_locks" {
  type = object({
    name = optional(string, "")
    type = optional(string, "CanNotDelete")
  })
  default = {}
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.nsg_locks.type)
    error_message = "Lock type must be one of: CanNotDelete, ReadOnly."
  }
}

variable "vnet_locks" {
  type = object({
    name = optional(string, "")
    type = optional(string, "CanNotDelete")
  })
  default = {}
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.vnet_locks.type)
    error_message = "Lock type must be one of: CanNotDelete, ReadOnly."
  }
}

variable "subnet_locks" {
  type = object({
    name = optional(string, "")
    type = optional(string, "CanNotDelete")
  })
  default = {}
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.subnet_locks.type)
    error_message = "Lock type must be one of: CanNotDelete, ReadOnly."
  }
}

variable "is_data_guard" {
  type        = bool
  description = "Whether Data Guard is enabled"
  default     = false
}

variable "tags" {
  type        = map(any)
  description = "Tags to be added to the resources"
  default     = {}
}
