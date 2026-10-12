locals {
  padded    = format("%03d", var.user_index)
  upn       = "user${local.padded}@${var.domain}"
  display   = "User ${local.padded}"
  mail_nick = "user${local.padded}"
}
