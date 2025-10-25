# ===============================================================================
# Entra ID Module - Variables
# ===============================================================================

variable "aks_deployment_group_name" {
  description = "Name of the Entra ID group for AKS deployment access"
  type        = string
}

variable "aks_deployment_group_description" {
  description = "Description of the Entra ID group for AKS deployment access"
  type        = string
  default     = "Security group with rights to deploy applications to the Oracle AKS cluster"
}


variable "tenant_id" {
  description = "Tenant ID where the Entra ID group should be created"
  type        = string
}



variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}