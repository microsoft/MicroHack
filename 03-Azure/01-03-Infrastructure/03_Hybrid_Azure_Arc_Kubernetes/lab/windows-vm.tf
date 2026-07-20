# ==============================================================================
# Windows 11 Workstation VM for MicroHack participants
# Provides a dev workstation with WSL, VS Code, and all prerequisite tools.
# After Terraform apply, run the Ansible playbook to install prerequisites.
# ==============================================================================

# --- Networking ---

resource "azurerm_subnet" "workstation" {
  count                = length(local.indices)
  name                 = "workstation-subnet"
  resource_group_name  = azurerm_resource_group.mh_k8s_onprem[count.index].name
  virtual_network_name = azurerm_virtual_network.onprem[count.index].name
  address_prefixes     = ["10.${100 + local.indices[count.index]}.2.0/24"]
}

resource "azurerm_network_security_group" "workstation" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-workstation-nsg"
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

  security_rule {
    name                       = "RDP-from-Bastion"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = cidrsubnet(var.bastion_vnet_address_space, 8, 0)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "WinRM-HTTPS-from-Bastion"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = cidrsubnet(var.bastion_vnet_address_space, 8, 0)
    destination_address_prefix = "*"
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

resource "azurerm_subnet_network_security_group_association" "workstation" {
  count                     = length(local.indices)
  subnet_id                 = azurerm_subnet.workstation[count.index].id
  network_security_group_id = azurerm_network_security_group.workstation[count.index].id
}

# --- NIC (no public IP — access via Bastion) ---

resource "azurerm_network_interface" "workstation" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-workstation-nic"
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workstation[count.index].id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.${100 + local.indices[count.index]}.2.10"
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# --- Windows 11 VM ---

resource "azurerm_windows_virtual_machine" "workstation" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-workstation"
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  size                = var.workstation_vm_size
  admin_username      = var.admin_user
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.workstation[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Windows 11 24H2 Pro — change sku to "win11-24h2-ent" if Pro is unavailable
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
    Role    = "workstation"
  }
}

# --- Enable WinRM via CustomScriptExtension for Ansible ---

resource "azurerm_virtual_machine_extension" "winrm" {
  count                = length(local.indices)
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.workstation[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -EncodedCommand ${textencodebase64(file("${path.module}/scripts/enable-winrm.ps1"), "UTF-16LE")}"
  })

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# --- Auto-shutdown schedule ---

resource "azurerm_dev_test_global_vm_shutdown_schedule" "workstation" {
  count              = length(local.indices)
  virtual_machine_id = azurerm_windows_virtual_machine.workstation[count.index].id
  location           = azurerm_resource_group.mh_k8s_onprem[count.index].location
  enabled            = true

  daily_recurrence_time = "1800"
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# --- Generate Ansible inventory and Bastion tunnel script ---

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible/inventory.yml.tpl", {
    indices            = local.indices
    workstation_ips    = [for nic in azurerm_network_interface.workstation : nic.private_ip_address]
    workstation_vm_ids = [for vm in azurerm_windows_virtual_machine.workstation : vm.id]
    admin_user         = var.admin_user
  })
  filename = "${path.module}/ansible/inventory.yml"
}

resource "local_file" "bastion_tunnel_script" {
  content = templatefile("${path.module}/ansible/open-bastion-tunnels.sh.tpl", {
    indices            = local.indices
    workstation_ips    = [for nic in azurerm_network_interface.workstation : nic.private_ip_address]
    workstation_vm_ids = [for vm in azurerm_windows_virtual_machine.workstation : vm.id]
    bastion_name       = azurerm_bastion_host.bastion.name
    bastion_rg         = azurerm_resource_group.bastion.name
  })
  filename        = "${path.module}/ansible/open-bastion-tunnels.sh"
  file_permission = "0755"
}

# --- Outputs ---

output "workstation_info" {
  value = {
    for i in range(length(local.indices)) :
    format("%02d", local.indices[i]) => {
      bastion_rdp = "az network bastion rdp --name ${azurerm_bastion_host.bastion.name} --resource-group ${azurerm_resource_group.bastion.name} --target-resource-id ${azurerm_windows_virtual_machine.workstation[i].id}"
      private_ip  = azurerm_network_interface.workstation[i].private_ip_address
      vm_id       = azurerm_windows_virtual_machine.workstation[i].id
    }
  }
}
