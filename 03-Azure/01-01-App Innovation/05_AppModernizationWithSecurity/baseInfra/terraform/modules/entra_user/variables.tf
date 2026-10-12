variable "user_index" {
  type        = number
  description = <<EOT
Numeric user index (1..n) aligned with per-user infra module.
Used only for generating deterministic UPN and display name (labuserNNN@domain).
EOT
}

variable "domain" {
  type        = string
  description = <<EOT
Entra ID tenant domain (custom or onmicrosoft.com) appended to generated UPN.
Example: contoso.onmicrosoft.com -> labuser001@contoso.onmicrosoft.com.
Must be non-empty when module is instantiated.
EOT
}

variable "password_length" {
  type        = number
  default     = 24
  description = <<EOT
Character length of the per-user password generated inside this module.
Every user receives a distinct random password that is never shared across participants
and must be changed at first sign-in. Read it from the root `entra_user_credentials`
sensitive output and distribute it to exactly one participant.
EOT

  validation {
    condition     = var.password_length >= 16 && var.password_length <= 64
    error_message = "password_length must be between 16 and 64 characters."
  }
}
