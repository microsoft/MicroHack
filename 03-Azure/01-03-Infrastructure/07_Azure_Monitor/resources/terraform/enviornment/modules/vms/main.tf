#----------------------------------------------------------------------------
# Create VM
#----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" vm-linux {
  name                  = "vm-linux"
  location              = var.location
  resource_group_name   = var.rg_name
  size                  = var.vm_sku
  admin_username        = var.vmuser
  // zone                  = "2"
  network_interface_ids = [
    azurerm_network_interface.nic_vm_linux.id,
  ]

  admin_ssh_key {
    username   = "vmuser"
    public_key = file("${path.module}/.ssh/id_rsa.pub")
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
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
    size                = var.vm_sku
    admin_username      = var.vmuser
    admin_password      = var.vmpassword
    // zone                = "2"
    network_interface_ids = [
      azurerm_network_interface.nic_vm_windows.id,
    ]

    identity {
      type = "SystemAssigned"
    }

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

# # TODO: Add Windows VM Extension
# ----------------------------------------------------------------------------
# Install IIS on Windows VM
# ----------------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "vm-extensions" {
  name                 = "vm-windows-ext"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm-windows.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"
    }
SETTINGS
}
