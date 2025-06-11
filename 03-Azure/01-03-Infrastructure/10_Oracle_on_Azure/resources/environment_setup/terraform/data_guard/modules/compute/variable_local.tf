locals {
  sid_auth_type        = try(var.database.authentication.type, "key")
  enable_auth_password = local.sid_auth_type == "password"
  enable_auth_key      = local.sid_auth_type == "key"
  tags                 = {}



  ### Variables for creating NICs
  database_ips = (var.use_secondary_ips) ? (
    flatten(concat(local.database_primary_ips, local.database_secondary_ips))) : (
    local.database_primary_ips
  )


  //ToDo: data.azurerm_subnet.subnet_oracle ???
  database_primary_ips = [
    {
      name                          = "IPConfig1"
      subnet_id                     = var.db_subnet.id
      nic_ips                       = var.database_nic_ips
      private_ip_address_allocation = var.database.use_DHCP ? "Dynamic" : "Static"
      offset                        = 0
      primary                       = true
      create_public_ip_address      = false
      public_ip_address_resource_id = var.public_ip_address_resource_id
    }
  ]

  database_secondary_ips = [
    {
      name                          = "IPConfig2"
      subnet_id                     = var.db_subnet.id
      nic_ips                       = var.database_nic_secondary_ips
      private_ip_address_allocation = var.database.use_DHCP ? "Dynamic" : "Static"
      offset                        = var.database_server_count
      primary                       = false
      create_public_ip_address      = false
      public_ip_address_resource_id = ""
    }
  ]

  network_interface_ipconfigs = { for ipconfig in local.database_ips : ipconfig.name => {
    name                          = ipconfig.name
    private_ip_subnet_resource_id = ipconfig.subnet_id
    create_public_ip_address      = ipconfig.create_public_ip_address
    public_ip_address_resource_id = ipconfig.public_ip_address_resource_id
    public_ip_address_name        = ipconfig.create_public_ip_address ? "${var.vm_name}-pip" : ""
    private_ip_address_allocation = ipconfig.private_ip_address_allocation
    is_primary_ipconfiguration    = ipconfig.primary
    private_ip_address            = var.database.use_DHCP ? ipconfig.nic_ips[0] : ""
    }
  }

  # role_assignments_nic_parameter = {for key, value in var.role_assignments_nic : key => {
  #   principal_id                           = value.principal_id
  #   role_definition_id_or_name             = value.role_definition_id_or_name
  #   assign_to_child_public_ip_addresses    = true
  #   skip_service_principal_aad_check      = value.skip_service_principal_aad_check
  # }



  vm_default_config_data = {
    "vm-0" = {
      name                               = var.vm_name
      os_type                            = "Linux"
      generate_admin_password_or_ssh_key = false
      enable_auth_password               = local.enable_auth_password
      admin_username                     = var.sid_username
      admin_ssh_keys = {
        username   = var.sid_username
        public_key = var.public_key
      }
      source_image_reference           = var.vm_source_image_reference
      virtualmachine_sku_size          = var.vm_sku
      os_disk                          = var.vm_os_disk
      availability_zone                = var.availability_zone
      enable_telemetry                 = var.enable_telemetry
      role_assignments                 = var.role_assignments
      skip_service_principal_aad_check = var.skip_service_principal_aad_check

      #Network Interfaces
      network_interfaces = {

        network_interface_1 = {
          name                           = "oraclevmnic-${var.vm_name}"
          location                       = var.location
          resource_group_name            = var.resource_group_name
          tags                           = merge(local.tags, var.tags)
          accelerated_networking_enabled = true

          ip_configurations = local.network_interface_ipconfigs

          #ToDo: role_assignments_nic_parameter
          # role_assignments = {
          #   role_assignment_1 = {
          #     role_definition_id_or_name       = "Contributor"
          #     principal_id                     = data.azurerm_client_config.current.object_id
          #     skip_service_principal_aad_check = var.skip_service_principal_aad_check
          #   }
          # }


        }
      }
    }
  }


  # Variable with the data to create the Oracle VM
  vm_config_data_parameter = merge(var.vm_config_data, local.vm_default_config_data)


}
