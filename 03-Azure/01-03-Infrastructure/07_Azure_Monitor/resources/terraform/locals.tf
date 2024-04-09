locals {
  tenant_id     = "4b893553-05c5-4133-979d-d91dbec74b21"
  group_obj_id  = "18d7347f-556e-46f4-a930-a4d946466750"
  enable_kv     = true
  kv_location   = "swedencentral"

  envs = {
    "01" : {
      location = "swedencentral",
      vm_sku   = "Standard_B1ls"
    } #,
    # "02" : {
    #   location = "germanywestcentral",
    #   vm_sku   = "Standard_B1ls"
    # },
    # "03" : {
    #   location = "germanywestcentral",
    #   vm_sku   = "Standard_B1ls"
    # },
    # "04" : {
    #   location = "germanywestcentral",
    #   vm_sku   = "Standard_B1ls"
    # },
    # "05" : {
    #   location = "swedencentral",
    #   vm_sku   = "Standard_B1ls"
    # },
    # "06" : {
    #   location = "swedencentral",
    #   vm_sku   = "Standard_B1ls"
    # },
    # "07" : {
    #   location = "swedencentral",
    #   vm_sku   = "Standard_B1ls"
    # },
    # "08" : {
    #   location = "swedencentral",
    #   vm_sku   = "Standard_B1ls"
    # }
  }
}