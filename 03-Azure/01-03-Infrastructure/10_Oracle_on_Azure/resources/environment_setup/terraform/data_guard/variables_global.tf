#########################################################################################
#  Common parameters                                                                    #
#########################################################################################
variable "location" {
  description = "Defines the Azure location where the resources will be deployed"
  type        = string
  default     = "germanywestcentral"
}

variable "resourcegroup_name" {
  description = "If defined, the name of the resource group into which the resources will be deployed"
  default     = "rg-mh-oracle4"
}

variable "resourcegroup_tags" {
  description = "tags to be added to the resource group"
  default     = {}
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

variable "infrastructure" {
  description = "Details of the Azure infrastructure to deploy the SAP landscape into"
  default     = {}
}

variable "disable_telemetry" {
  type        = bool
  description = "If set to true, will disable telemetry for the module. See https://aka.ms/alz-terraform-module-telemetry."
  default     = false
}
#########################################################################################
#  Virtual Machine parameters                                                           #
#########################################################################################
variable "ssh_key" {
  description = "value of the ssh public key to be used for the virtual machines"
}

variable "vm_sku" {
  description = "The SKU of the virtual machine"
  default     = "Standard_E4ds_v5"
}

variable "vm_source_image_reference" {
  description = "The source image reference of the virtual machine"
  default = {
    publisher = "Oracle"
    offer     = "oracle-database-19-3"
    sku       = "oracle-database-19-0904"
    version   = "latest"
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

variable "jit_wait_for_vm_creation" {
  description = "The duration to wait for the virtual machine to be created before creating the JIT policy"
  default     = "60s"
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


#########################################################################################
#  Database parameters                                                                  #
#########################################################################################
variable "database" {
  description = "Details of the database node"
  default = {
    use_DHCP = true
    authentication = {
      type = "key"
    }
    data_disks = [
      {
        count                     = 1
        caching                   = "ReadOnly"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 0
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      },
      {
        count                     = 1
        caching                   = "None"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 1
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ]
  }
}

variable "database_disks_options" {
  description = "Details of the database node"
  default = {
    data_disks = [
      {
        count                     = 1
        caching                   = "ReadOnly"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 1
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ],
    asm_disks = [
      {
        count                     = 1
        caching                   = "ReadOnly"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 0
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ]
    redo_disks = [
      {
        count                     = 1
        caching                   = "None"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 2
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ]
  }
}

variable "database_db_nic_ips" {
  description = "If provided, the database tier virtual machines will be configured using the specified IPs"
  default     = [""]
}
