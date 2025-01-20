variable "location" {
  description = "The Azure region where the resources will be deployed"
  type        = string
  # In the microhack subscription there is a deployment limit of 10 cores per VM type per region.
  # Please align with your coach what region you should use to avoid hitting the limit.
  default     = "germanywestcentral"  
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "challenge-1" # you should add a unique prefix (i.e. your name) here to avoid name collisions with your co-participants
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_E2bds_v5" # change this according the the sizing determined in the previous challenge
}

variable "path_to_ssh_key_file" {
  description = "The path to the SSH public key file"
  type        = string
  default     = "~/.ssh/oracle_vm_rsa_id.pub" # only change this if you used another path or name for your key file.
}

# change the size, IOPS and throughput of each disk according to the requirements.
# Please note: It's recommended to separate at least the disks or database files, redo logs and other files.
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

# no need to change the below parameters for the microhack

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

variable "vm_username" {
  description = "The admin username for the virtual machine"
  type        = string
  default     = "adminuser"
}