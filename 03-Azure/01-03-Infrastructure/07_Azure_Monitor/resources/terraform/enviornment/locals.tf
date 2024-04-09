locals {
    appgw_name          = "appgw-microhack-${var.prefix}"
    appgw_pip_name      = "pip-appgw-microhack-${var.prefix}"

    bastion_name        = "bastion-microhack-${var.prefix}"
    bastion_pip_name    = "pip-bastion-${var.prefix}"

    virtual_network_name  = "vnet-microhack-${var.prefix}"
    subnet_name           = "subnet-microhack-${var.prefix}"
    nsg_name              = "nsg-microhack-${var.prefix}"

    vmss_name             = "vmss-linux-nginx-${var.prefix}"

    vm_win_name           = "vm-win-${var.prefix}"
    vm_linux_name         = "vm-linux-${var.prefix}"
}