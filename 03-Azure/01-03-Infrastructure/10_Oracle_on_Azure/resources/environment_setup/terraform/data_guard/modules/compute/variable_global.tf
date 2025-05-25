variable "database_server_count" {
  description = "The number of database servers"
  default     = 1
  type        = number
}

variable "vm_name" {
  description = "The name of the Oracle VM"
  type        = string
}

# variable "resource_group" {
#   description = "Details of the resource group"
#   default     = {}
# }


variable "resource_group_name" {
  description = "Created resource group name"
  type        = string
}

variable "location" {
  description = "The location of the resource"
  type        = string
}



variable "database" {
  description = "Details of the database node"
  type = object({
    use_DHCP = string
    authentication = object({
      type = string
    })
  })
  default = {
    use_DHCP = true
    authentication = {
      type = "key"
    }
  }
}

variable "nic_locks" {
  type = object({
    name = optional(string, "")
    type = optional(string, "CanNotDelete")
  })
  default = {}
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly"], var.nic_locks.type)
    error_message = "Lock type must be one of: CanNotDelete, ReadOnly."
  }
}

variable "aad_system_assigned_identity" {
  description = "AAD system assigned identity"
  type        = bool
}

variable "skip_service_principal_aad_check" {
  type = bool
  description = "If the principal_id is a newly provisioned `Service Principal` set this value to true to skip the Azure Active Directory check which may fail due to replication lag."
  default     = true
}

variable "storage_account_id" {
  description = "Storage account ID used for diagnostics"
  type        = string
  default     = null
}

variable "storage_account_sas_token" {
  description = "Storage account SAS token used for diagnostics"
  type        = string
  default     = null
}

variable "log_analytics_workspace" {
  type = object({
    id   = string
    name = string
  })

  description = "Log Analytics workspace"
  default     = null
}

variable "eventhub_authorization_rule_id" {
  description = "ID of an Event Hub authorization rule"
  type        = string
  default     = null
}

variable "partner_solution_id" {
  description = "Value of the partner solution ID"
  default     = null
}

variable "is_diagnostic_settings_enabled" {
  description = "Whether diagnostic settings are enabled"
  default     = false
}

variable "diagnostic_target" {
  description = "The destination type of the diagnostic settings"
  default     = "Log_Analytics_Workspace"
  validation {
    condition     = contains(["Log_Analytics_Workspace", "Storage_Account", "Event_Hubs", "Partner_Solutions"], var.diagnostic_target)
    error_message = "Allowed values are Log_Analytics_Workspace, Storage_Account, Event_Hubs, Partner_Solutions"
  }
}

variable "data_collection_rules" {
  type = map(object({
    id = string
  }))
  description = "Data collection rules"
  default     = {}
}

# variable "role_assignments" {
#   description = "Role assignments"
#   default     = {}
# }

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool, true)
    delegated_managed_identity_resource_id = optional(string)
    }
  ))
  default = {}
}

variable "vm_lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
  default     = {}
  description = <<LOCK
"The lock level to apply to this virtual machine and all of it's child resources. The default value is none. Possible values are `None`, `CanNotDelete`, and `ReadOnly`. Set the lock value on child resource values explicitly to override any inherited locks." 

Example Inputs:
```hcl
lock = {
  name = "lock-{resourcename}" # optional
  type = "CanNotDelete" 
}
```
LOCK
  nullable    = false

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.vm_lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}


variable "tags" {
  description = "Tags to be added to the resources"
  default     = {}
}

variable "vm_sku" {
  description = "The SKU of the virtual machine"
  default     = "Standard_D4s_v3"
}

variable "vm_source_image_reference" {
  description = "The source image reference of the virtual machine"
  default = {
    publisher = "Oracle"
    offer     = "Oracle-Linux"
    sku       = "79-gen2"
    version   = "7.9.36"
  }
}

variable "vm_os_disk" {
  description = "Details of the OS disk"
  default = {
    name                   = "osdisk"
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = null
    disk_size_gb           = 128
  }
}

variable "availability_zone" {
  description = "The availability zones of the resource"
  default     = null
}

variable "vm_extensions" {
  description = "The extensions to be added to the virtual machine"
  type = map(object({
    name                        = string
    publisher                   = string
    type                        = string
    type_handler_version        = string
    auto_upgrade_minor_version  = optional(bool)
    automatic_upgrade_enabled   = optional(bool)
    failure_suppression_enabled = optional(bool, false)
    settings                    = optional(string)
    protected_settings          = optional(string)
    provision_after_extensions  = optional(list(string), [])
    tags                        = optional(map(any))
    protected_settings_from_key_vault = optional(object({
      secret_url      = string
      source_vault_id = string
    }))
  }))
  default = {}
}


variable "enable_telemetry" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}


# variable "is_data_guard" {
#   description = "Whether Data Guard is enabled"
#   default     = false
# }


###Variables for creating NICs
variable "use_secondary_ips" {
  description = "Defines if secondary IPs are used for the SAP Systems virtual machines"
  default     = false
}

variable "database_nic_ips" {
  description = "If provided, the database tier virtual machines will be configured using the specified IPs"
  default     = [""]
}

variable "database_nic_secondary_ips" {
  description = "If provided, the database tier virtual machines will be configured using the specified IPs as secondary IPs"
  default     = [""]
}

variable "db_subnet" {
  description = "Details of the database subnet"
  default     = {}
}

variable "sid_username" {
  description = "SDU username"
  type        = string
}

variable "public_key" {
  description = "Public key used for authentication in ssh-rsa format"
  type        = string
}


variable "enable_ultradisk" {
  description = "Enable Ultra Disk"
  type        = bool
  default     = false
}

variable "enable_hibernation" {
  description = "Enable Hibernation"
  type        = bool
  default     = false
}

variable "public_ip_address_resource_id" {
  description = "The resource id of the public IP address"
  type        = string
  default     = null

}

variable "role_assignments_nic" {
  description = "Role assignments scoped to the network interface"
  default     = {}
  type = map(object({
    principal_id                           = string
    role_definition_id_or_name             = string
    assign_to_child_public_ip_addresses    = optional(bool, true)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
  }))
}

variable "vm_config_data" {
  description = "VM configuration data"

  type = map(object({

    name                               = string
    os_type                            = string
    generate_admin_password_or_ssh_key = bool
    enable_auth_password               = bool
    admin_username                     = string
    virtualmachine_sku_size            = string
    availability_zone                  = string
    enable_telemetry                   = bool
    encryption_at_host_enabled         = bool
    zone                               = string
    user_assigned_identity_id          = string

    admin_ssh_keys = object({
      public_key = string
      username   = string

    })
    os_disk = object({
      name                   = string
      caching                = string
      storage_account_type   = string
      disk_encryption_set_id = number
      disk_size_gb           = number
    })

    source_image_reference = object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    })

    role_assignments = map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
    }))

  }))


  default = null
}
