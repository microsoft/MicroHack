####################################################
# interfaces
####################################################

resource "azurerm_network_interface" "nic" {
  resource_group_name   = var.resource_group
  name                  = var.name
  location              = var.location
  
  ip_configuration {
    primary                       = true
    name                          = var.name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }
}

####################################################
# virtual machine
####################################################

resource "azurerm_linux_virtual_machine" "vm" {
  resource_group_name = var.resource_group
  name                = var.name
  location            = var.location
  zone                = var.zone
  size                = var.vm_size
  custom_data         = var.use_vm_custom_data ? null : var.custom_data
  network_interface_ids = [azurerm_network_interface.nic.id]
  os_disk {
    name                 = var.name
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = var.source_image_publisher
    offer     = var.source_image_offer
    sku       = var.source_image_sku
    version   = var.source_image_version
  }
  computer_name  = var.name
  admin_username = var.username
  admin_password = var.password
  boot_diagnostics {}
  disable_password_authentication = false

  identity {
    type = "SystemAssigned"
  }
}

####################################################
# virtual machine extension
####################################################

resource "azurerm_virtual_machine_extension" "vm_extension" {
  name                 = "${var.name}networkWatcherAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.NetworkWatcher"
  type                 = "NetworkWatcherAgentLinux"
  type_handler_version = "1.4"
  depends_on           = [azurerm_linux_virtual_machine.vm]
}

resource "azurerm_virtual_machine_extension" "aad_ssh" {
  name                 = var.name
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
  depends_on           = [azurerm_linux_virtual_machine.vm]
}

####################################################
# RBAC
####################################################

resource "azurerm_role_assignment" "vm_admin" {
  principal_id   = var.admin_principal_id
  role_definition_name = "Virtual Machine Administrator Login"
  scope          = azurerm_linux_virtual_machine.vm.id
}