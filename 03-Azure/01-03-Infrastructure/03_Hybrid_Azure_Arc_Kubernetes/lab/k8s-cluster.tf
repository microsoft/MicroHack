# Create Virtual Network for K3s cluster
resource "azurerm_virtual_network" "onprem" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-vnet"
  address_space       = ["10.${100 + local.indices[count.index]}.0.0/16"]
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# Create subnet for K3s VMs
resource "azurerm_subnet" "onprem" {
  count                = length(local.indices)
  name                 = "k3s-subnet"
  resource_group_name  = azurerm_resource_group.mh_k8s_onprem[count.index].name
  virtual_network_name = azurerm_virtual_network.onprem[count.index].name
  address_prefixes     = ["10.${100 + local.indices[count.index]}.1.0/24"]
}

# Create Network Security Group for K3s VMs
resource "azurerm_network_security_group" "onprem" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-nsg"
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

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

  security_rule {
    name                       = "K3s-API"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "K3s-NodePort"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# Associate Network Security Group to the subnet
resource "azurerm_subnet_network_security_group_association" "onprem" {
  count                  = length(local.indices)
  subnet_id              = azurerm_subnet.onprem[count.index].id
  network_security_group_id = azurerm_network_security_group.onprem[count.index].id
}

# Create public IPs for K3s VMs
resource "azurerm_public_ip" "onprem_master" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-master-ip"
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  allocation_method   = "Static"

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

resource "azurerm_public_ip" "onprem_worker" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-worker1-ip"
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  allocation_method   = "Static"

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

resource "azurerm_public_ip" "onprem_worker2" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-worker2-ip"
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  allocation_method   = "Static"

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# Create Network Interfaces
resource "azurerm_network_interface" "onprem_master" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-master-nic"
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem[count.index].id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.${100 + local.indices[count.index]}.1.10"
    public_ip_address_id          = azurerm_public_ip.onprem_master[count.index].id
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

resource "azurerm_network_interface" "onprem_worker" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-worker1-nic"
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem[count.index].id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.${100 + local.indices[count.index]}.1.11"
    public_ip_address_id          = azurerm_public_ip.onprem_worker[count.index].id
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

resource "azurerm_network_interface" "onprem_worker2" {
  count               = length(local.indices)
  name                = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-worker2-nic"
  location            = azurerm_resource_group.mh_k8s_onprem[count.index].location
  resource_group_name = azurerm_resource_group.mh_k8s_onprem[count.index].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem[count.index].id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.${100 + local.indices[count.index]}.1.12"
    public_ip_address_id          = azurerm_public_ip.onprem_worker2[count.index].id
  }

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
  }
}

# Create K3s Master VM
resource "azurerm_linux_virtual_machine" "onprem_master" {
  count                           = length(local.indices)
  name                            = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-master"
  resource_group_name             = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location                        = azurerm_resource_group.mh_k8s_onprem[count.index].location
  size                            = var.vm_size
  disable_password_authentication = false
  admin_username                  = var.admin_user
  admin_password                  = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.onprem_master[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/k3s-master-setup.sh", {
    k3s_version = var.k3s_version
    cluster_token = var.cluster_token
    admin_user = var.admin_user
  }))

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
    Role    = "master"
  }
}

# Create K3s Worker VM 1
resource "azurerm_linux_virtual_machine" "onprem_worker" {
  count                           = length(local.indices)
  name                            = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-worker1"
  resource_group_name             = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location                        = azurerm_resource_group.mh_k8s_onprem[count.index].location
  size                            = var.vm_size
  disable_password_authentication = false
  admin_username                  = var.admin_user
  admin_password                  = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.onprem_worker[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/k3s-worker-setup.sh", {
    k3s_version = var.k3s_version
    cluster_token = var.cluster_token
    master_ip = "10.${100 + local.indices[count.index]}.1.10"
    admin_user = var.admin_user
  }))

  depends_on = [azurerm_linux_virtual_machine.onprem_master]

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
    Role    = "worker"
  }
}

# Create K3s Worker VM 2
resource "azurerm_linux_virtual_machine" "onprem_worker2" {
  count                           = length(local.indices)
  name                            = "${format("%02d", local.indices[count.index])}-${var.resource_group_base_name}-worker2"
  resource_group_name             = azurerm_resource_group.mh_k8s_onprem[count.index].name
  location                        = azurerm_resource_group.mh_k8s_onprem[count.index].location
  size                            = var.vm_size
  disable_password_authentication = false
  admin_username                  = var.admin_user
  admin_password                  = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.onprem_worker2[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/k3s-worker-setup.sh", {
    k3s_version = var.k3s_version
    cluster_token = var.cluster_token
    master_ip = "10.${100 + local.indices[count.index]}.1.10"
    admin_user = var.admin_user
  }))

  depends_on = [azurerm_linux_virtual_machine.onprem_master]

  tags = {
    Project = "simulated onprem k8s cluster for microhack"
    Role    = "worker"
  }
}

# Auto-shutdown schedule for K3s Master VMs
resource "azurerm_dev_test_global_vm_shutdown_schedule" "master" {
  count              = length(local.indices)
  virtual_machine_id = azurerm_linux_virtual_machine.onprem_master[count.index].id
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

# Auto-shutdown schedule for K3s Worker1 VMs
resource "azurerm_dev_test_global_vm_shutdown_schedule" "worker" {
  count              = length(local.indices)
  virtual_machine_id = azurerm_linux_virtual_machine.onprem_worker[count.index].id
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

# Auto-shutdown schedule for K3s Worker2 VMs
resource "azurerm_dev_test_global_vm_shutdown_schedule" "worker2" {
  count              = length(local.indices)
  virtual_machine_id = azurerm_linux_virtual_machine.onprem_worker2[count.index].id
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

output "k3s_cluster_info" {
  value = {
    for i in range(length(local.indices)) :
    format("%02d", local.indices[i]) => {
      master_ssh    = "ssh ${var.admin_user}@${azurerm_public_ip.onprem_master[i].ip_address}"
      worker1_ssh   = "ssh ${var.admin_user}@${azurerm_public_ip.onprem_worker[i].ip_address}"
      worker2_ssh   = "ssh ${var.admin_user}@${azurerm_public_ip.onprem_worker2[i].ip_address}"
      kubeconfig_setup = "mkdir -p ~/.kube && scp ${var.admin_user}@${azurerm_public_ip.onprem_master[i].ip_address}:/home/${var.admin_user}/.kube/config ~/.kube/config && sed -i 's/127.0.0.1/${azurerm_public_ip.onprem_master[i].ip_address}/g' ~/.kube/config"
    }
  }
}