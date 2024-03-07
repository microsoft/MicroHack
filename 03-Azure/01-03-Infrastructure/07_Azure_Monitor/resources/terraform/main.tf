module "resource_groups" {
  for_each  = local.envs

  source    = "./enviornment"

  rg_name   = "${var.rg_name}-u${each.key}"
  location  = "${each.value.location}"
  vm_sku    = "${each.value.vm_sku}"
  prefix    = "u${each.key}"
}