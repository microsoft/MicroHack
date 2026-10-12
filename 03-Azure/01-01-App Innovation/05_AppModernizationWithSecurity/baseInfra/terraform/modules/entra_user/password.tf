resource "random_password" "this" {
  length           = var.password_length
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#$%*+-=?@^_"
}
