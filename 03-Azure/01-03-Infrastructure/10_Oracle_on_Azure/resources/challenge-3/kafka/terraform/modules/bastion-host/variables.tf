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



