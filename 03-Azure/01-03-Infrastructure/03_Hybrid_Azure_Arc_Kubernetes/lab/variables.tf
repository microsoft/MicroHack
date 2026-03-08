variable "start_index" {
  description = "Starting index for resource naming"
  type        = number
  default     = 37
}

variable "end_index" {
  description = "Ending index for resource naming"
  type        = number
  default     = 39
}

variable "arc_location" {
  description = "The Azure Region in which all resources for Azure Arc should be provisioned"
  default     = "westeurope"
}

variable "onprem_resources" {
  description = "The Azure Regions in which K3s cluster VMs should be provisioned"
  default     = ["francecentral", "swedencentral", "germanywestcentral", "northeurope", "uksouth"]
}

variable "resource_group_base_name" {
  description = "Base name for resource groups (will be prefixed with index)"
  default     = "k8s"
}

variable "k3s_cluster_base_name" {
  description = "Base name for K3s cluster resources"
  default     = "k3s-onprem"
}

variable "prefix" {
  description = "A prefix used for all K3s cluster resources"
  default     = "k3s"
}

variable "k3s_version" {
  description = "K3s version to install"
  default     = "v1.33.6+k3s1" 
}

variable "cluster_token" {
  description = "Token for K3s cluster authentication"
  type        = string
  sensitive = true
}

variable "admin_user" {
  description = "Admin username for VMs"
  type        = string
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "The Azure VM size for K3s nodes"
  default     = "Standard_D4ds_v6" # For arc-enabled Managed SQL Instances, ARM cores not supported
}

# container reguistry variables for gitops challenge
variable "acr_name" {
    description = "The name of the Azure Container Registry"
    default     = "mhacr"
}

variable "container_registry_sku" {
    description = "The SKU of the Azure Container Registry"
    default     = "Basic"
}

variable "container_registry_admin_enabled" {
    description = "Specifies whether the admin user is enabled. Defaults to false."
    type        = bool
    default     = true
}
