#########################################################################################
#  storage account for Oracle installation binaries                                     #
#########################################################################################
variable "storage_rg_name" {
  description = "The name of the resource group where the storage account will be created"
  default     = "rg-mh-oracle-bin"
}

variable "sa_name" {
  description = "The name of the storage account"
  default     = "mhorabinstoregwc71438"
}

variable "container_name" {
  description = "The name of the blob container where the binaries will be stored"
  default     = "oracle-bin"
}

variable "user_managed_identity" {
  description = "The name for the user managed identity for access to the storage account"
  default     = "ora-bin-access"
}

variable "location" {
  description = "The location of the storage account"
  default     = "germanywestcentral"
}