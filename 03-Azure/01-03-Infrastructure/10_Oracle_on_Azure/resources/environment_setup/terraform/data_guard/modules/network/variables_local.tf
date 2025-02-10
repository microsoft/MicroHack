locals {
  vnet_oracle_name       = "vnet1"
  database_subnet_name   = "subnet1"
  vnet_oracle_addr       = "10.0.0.0/16"
  database_subnet_prefix = "10.0.0.0/24"

  vnet_oracle_arm_id   = try(local.vnet_oracle_name.arm_id, "")
  vnet_oracle_exists   = length(local.vnet_oracle_arm_id) > 0
  subnet_oracle_arm_id = try(local.database_subnet_name.arm_id, "")
  subnet_oracle_exists = length(local.subnet_oracle_arm_id) > 0

  tags = {}
}
