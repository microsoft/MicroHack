variable "subscription_id" {
  description = "A prefix used for all resources in this example."
  type        = string
}

variable "prefix" {
  description = "A prefix used for all resources in this example."
  type        = string
}

variable "location" {
  description = "The Azure Region in which all resources will be created."
  type        = string
  default     = "Germany West Central"
}

variable "username" {
  description = "The username for the Virtual Machines."
  type        = string
  default     = "chpinoto"
}

variable "password" {
  description = "The password for the Virtual Machines."
  type        = string
  default     = "demo!pass123"
}

variable "vm_custom_data_linux" {
  description = "The password for the Virtual Machines."
  type        = string
  default     = "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
}