#----------------------------------------------------------------------------
# Create VM
#----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" vm-linux {
  name                  = "vm-linux"
  location              = var.location
  resource_group_name   = var.rg_name
  size                = "Standard_F2"
  admin_username      = "vmuser"
  network_interface_ids = [
    azurerm_network_interface.nic_vm_linux.id,
  ]

  admin_ssh_key {
    username   = "vmuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22.04-LTS"
    version   = "latest"
  }
}


#----------------------------------------------------------------------------
# Create nic (Linux)
#----------------------------------------------------------------------------
resource "azurerm_network_interface" "nic_vm_linux" {
  name                = "nic-vm-linux"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "ipconfig-vm-linux"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}


#----------------------------------------------------------------------------
# Create Windows VM
#----------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "vm-windows" {
    name                = "vm-windows"
    location            = var.location
    resource_group_name = var.rg_name
    size                = "Standard_F2"
    admin_username      = "vmuser"
    admin_password      = "P@ssw0rd1234!"
    network_interface_ids = [
      azurerm_network_interface.nic_vm_windows.id,
    ]

    os_disk {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }

    source_image_reference {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2019-Datacenter"
      version   = "latest"
    }
  }

#----------------------------------------------------------------------------
# Create NIC (Windows)
#----------------------------------------------------------------------------
resource "azurerm_network_interface" "nic_vm_windows" {
  name                = "nic-vm-windows"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "ipconfig-vm-windows"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}