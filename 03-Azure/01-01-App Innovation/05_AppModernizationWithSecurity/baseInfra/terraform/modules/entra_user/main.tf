resource "azuread_user" "this" {
  user_principal_name   = local.upn
  display_name          = local.display
  password              = random_password.this.result
  force_password_change = true
  mail_nickname         = local.mail_nick
}
