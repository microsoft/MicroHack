variable "location" {
  description = "The Azure region where the resources will be deployed"
  type        = string
  default     = "germanywestcentral"  
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "challenge-1"
  
}

variable "availability_zone" {
  description = "The availability zone for the virtual machine"
  type        = string
  default     = "1"
}

variable "vm_name" {
  description = "name of the virtual machine"
  type        = string
  default     = "ora-vm"
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_E2bds_v5"
}

variable "vm_username" {
  description = "The admin username for the virtual machine"
  type        = string
  default     = "adminuser"
}

variable "path_to_ssh_key_file" {
  description = "The path to the SSH public key file"
  type        = string
  default     = "~/.ssh/lza-oracle-single-instance.pub"
}

variable "data_disk_config" {
  description = "The configuration for the data disks"
  type        = map(object({
    name      = string
    size_gb   = number
    iops      = number
    throughput = number
    caching = string
  }))
  default = {
    data_disk = {
      name      = "data_disk"
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
    asm_disk = {
      name      = "asm_disk"
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
    redo_disk = {
      name      = "redo_disk"
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
  }
}