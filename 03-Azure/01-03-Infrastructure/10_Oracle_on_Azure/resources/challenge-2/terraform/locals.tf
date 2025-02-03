locals {
    vnet_name           = "${var.vm_name}-vnet"
    vnet_cidr           = ["10.0.0.0/16"]
    subnet_name         = "${var.vm_name}-subnet"
    subnet_cidr         = ["10.0.1.0/24"]
    nic_name            = "${var.vm_name}-nic"
    pip_name            = "${var.vm_name}-pip"
    nsg_name            = "${var.vm_name}-nsg"
}