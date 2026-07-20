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

variable "user_principal_domain" {
  description = "Optional domain used to construct user principal names when not supplied in the user catalog"
  type        = string
  default     = null
}

variable "users" {
  description = "Map of user definitions keyed by deployment identifier"
  type = map(object({
    identifier = string
  }))
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "user_password_length" {
  description = "Length of the generated user passwords."
  type        = number
  default     = 12
}

variable "user_password_include_special" {
  description = "Set to true to include special characters in generated passwords."
  type        = bool
  default     = false
}

variable "user_password_special_characters" {
  description = "Special characters to use when user_password_include_special is true."
  type        = string
  default     = "!#$%&*()-_=+[]{}"
}

variable "user_password_min_numeric" {
  description = "Minimum numeric characters in the generated user passwords."
  type        = number
  default     = 1
}