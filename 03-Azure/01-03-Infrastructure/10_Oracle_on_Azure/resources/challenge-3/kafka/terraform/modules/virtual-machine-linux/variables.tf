variable "resource_group" {
  description = "resource group name"
  type        = any
}

variable "name" {
  description = "virtual machine resource name"
  type        = string
}

variable "subnet_id" {
  type        = string
}

variable "location" {
  description = "vnet region location"
  type        = string
}

variable "zone" {
  description = "availability zone for supported regions"
  type        = string
  default     = "1"
}

variable "vm_size" {
  description = "size of vm"
  type        = string
  default     = "Standard_B2s"
}

variable "ssh_public_key" {
  description = "sh public key data"
  type        = string
  default     = null
}

variable "username" {
  description = "admin username"
  type        = string
  default     = "chpinoto"
}

variable "password" {
  description = "admin password"
  type        = string
  default     = "Password123"
}

variable "use_vm_custom_data" {
  type        = bool
  default     = false
}

variable "custom_data" {
  description = "base64 string containing virtual machine custom data"
  type        = string
  default     = null
}

variable "source_image_publisher" {
  description = "source image reference publisher"
  type        = string
  default     = "Canonical"
}

variable "source_image_offer" {
  description = "source image reference offer"
  type        = string
  default     = "0001-com-ubuntu-server-focal"
}

variable "source_image_sku" {
  description = "source image reference sku"
  type        = string
  default     = "20_04-lts"
}

variable "source_image_version" {
  description = "source image reference version"
  type        = string
  default     = "latest"
}

variable "source_image_reference_library" {
  description = "source image reference"
  type        = map(any)
  default = {
    "cisco-csr-1000v" = {
      publisher = "cisco"
      offer     = "cisco-csr-1000v"
      sku       = "17_3_4a-byol"
      version   = "latest"
    }
    "cisco-c8000v" = {
      publisher = "cisco"
      offer     = "cisco-c8000v"
      sku       = "17_11_01a-byol"
      version   = "latest"
    }
    "ubuntu-18" = {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
    }
    "ubuntu-20" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts"
      version   = "latest"
    }
    "ubuntu-22" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts"
      version   = "latest"
    }
    "debian-10" = {
      publisher = "Debian"
      offer     = "debian-10"
      sku       = "10"
      version   = "0.20201013.422"
    }
    "freebsd-13" = {
      publisher = "thefreebsdfoundation"
      offer     = "freebsd-13_1"
      sku       = "13_1-release"
      version   = "latest"
    }
  }
}

variable "images_with_plan" {
  description = "images with plan"
  type        = list(string)
  default = [
    "cisco-csr-1000v",
    "cisco-c8000v",
    "freebsd-13"
  ]
}

variable "admin_principal_id" {
  type        = string
}