resource "azurerm_linux_virtual_machine_scale_set" "nginx_vmss" {
  name                = "vmss-linux-nginx"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = var.vm_sku
  instances           = 1
  admin_username      = "vmuser"
  // upgrade_mode        = "Automatic"

  custom_data = base64encode(file("${path.module}/web.conf"))

  admin_ssh_key {
    username   = "vmuser"
    public_key = file("${path.module}/modules/vms/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.microhack_subnet[0].id
      # application_gateway_backend_address_pool_ids = azurerm_application_gateway.appgw.backend_address_pool_ids
      application_gateway_backend_address_pool_ids = azurerm_application_gateway.appgw.backend_address_pool[*].id
    }
  }

  depends_on = [ azurerm_application_gateway.appgw ]
}