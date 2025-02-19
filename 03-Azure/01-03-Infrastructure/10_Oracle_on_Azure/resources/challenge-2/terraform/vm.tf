# create a new Azure VM including a new vnet and subnet with the following requirements:
# image: Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1
# size: use input parameter "vm_size"
# username: use input parameter "vm_username"
# ssh_key: use input parameter "path_to_ssh_key_file"


resource "azurerm_resource_group" "rg" {
name     = var.resource_group_name
location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  address_space       = local.vnet_cidr
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = local.subnet_cidr
}

resource "azurerm_public_ip" "public_ip" {
  name                  = local.pip_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  allocation_method     = "Static"
  zones                 = [var.availability_zone]
  sku                   = "Standard"
  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = local.nsg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = local.nic_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg-nic-assignment" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nsg-subnet-assignment" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_managed_disk" "data_disk" {
    count                       = length(var.data_disk_config)
    name                        = element(keys(var.data_disk_config), count.index)
    location                    = azurerm_resource_group.rg.location
    zone                        = var.availability_zone
    resource_group_name         = azurerm_resource_group.rg.name
    storage_account_type        = "PremiumV2_LRS"
    create_option               = "Empty"
    disk_size_gb                = var.data_disk_config[element(keys(var.data_disk_config), count.index)].size_gb
    disk_iops_read_write        = var.data_disk_config[element(keys(var.data_disk_config), count.index)].iops
    disk_mbps_read_write        = var.data_disk_config[element(keys(var.data_disk_config), count.index)].throughput
}

data "azurerm_user_assigned_identity" "user_assigned_identity" {
  name                = var.user_assigned_identity.name
  resource_group_name = var.user_assigned_identity.resource_group
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.vm_username
  zone                = var.availability_zone
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = file(var.path_to_ssh_key_file)
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.user_assigned_identity.id
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku 
    version   = var.vm_image.version
  }

  computer_name  = var.vm_name
  disable_password_authentication = true
}

# attach data disks to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk" {
  count              = length(var.data_disk_config)
  managed_disk_id    = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = count.index
  caching            = var.data_disk_config[element(keys(var.data_disk_config), count.index)].caching
}

resource "azurerm_virtual_machine_extension" "install_prerequisites" {
  name                 = "install_prerequisites" # python 3.8 and NVMe configuration
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
  
  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.data_disk
  ]

  settings = <<SETTINGS
    {
        "script": "${filebase64("./prerequisites_script.sh")}"
    }
SETTINGS
}

output "vm_public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}