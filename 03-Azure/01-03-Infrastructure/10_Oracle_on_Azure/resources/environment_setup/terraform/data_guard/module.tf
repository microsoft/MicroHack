data "azurerm_client_config" "current" {}

module "common_infrastructure" {
  source = "./modules/common_infrastructure"

  infrastructure                 = local.infrastructure
  is_data_guard                  = true
  is_diagnostic_settings_enabled = var.is_diagnostic_settings_enabled
  diagnostic_target              = var.diagnostic_target
  tags                           = var.resourcegroup_tags

}

module "vm_primary" {
  source = "./modules/compute"

  resource_group_name = module.common_infrastructure.created_resource_group_name
  location            = var.location
  vm_name             = "vm-primary-0"
  public_key          = var.ssh_key
  sid_username        = "oracle"
  vm_sku              = var.vm_sku

  vm_source_image_reference     = var.vm_source_image_reference
  aad_system_assigned_identity  = true
  public_ip_address_resource_id = module.network.db_server_puplic_ip_resources[0].id


  is_diagnostic_settings_enabled = module.common_infrastructure.is_diagnostic_settings_enabled
  diagnostic_target              = module.common_infrastructure.diagnostic_target
  storage_account_id             = module.common_infrastructure.target_storage_account_id
  storage_account_sas_token      = module.common_infrastructure.target_storage_account_sas
  log_analytics_workspace = module.common_infrastructure.log_analytics_workspace != null ? {
    id   = module.common_infrastructure.log_analytics_workspace.id
    name = module.common_infrastructure.log_analytics_workspace.name
  } : null
  data_collection_rules          = module.common_infrastructure.data_collection_rules
  eventhub_authorization_rule_id = module.common_infrastructure.eventhub_authorization_rule_id
  partner_solution_id            = module.common_infrastructure.partner_solution_id
  tags                           = module.common_infrastructure.tags
  db_subnet                      = module.network.db_subnet

  availability_zone = 1


  vm_os_disk = {
    name                   = "osdisk-primary"
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = null
    disk_size_gb           = 128
  }

  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name       = "Virtual Machine Contributor"
      principal_id                     = data.azurerm_client_config.current.object_id
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_nic = {
    role_assignment_1 = {
      role_definition_id_or_name       = "Contributor"
      principal_id                     = data.azurerm_client_config.current.object_id
      skip_service_principal_aad_check = false
    }
  }

  vm_extensions = {
    azure_monitor_agent = {
      name                       = "vm-primary-azure-monitor-agent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorLinuxAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      automatic_upgrade_enabled  = true
      settings                   = null
    },
    custom_script_extension_linux = {
      name = "CustomScriptExtension"
      publisher = "Microsoft.Azure.Extensions"
      type = "CustomScript"
      type_handler_version = "2.0"
      settings =<<SETTINGS
      {
        "commandToExecute": "sudo yum install -y gcc openssl-devel libffi-devel bzip2-devel wget && cd /opt && sudo wget https://www.python.org/ftp/python/3.8.9/Python-3.8.9.tgz && sudo tar xzvf Python-3.8.9.tgz && cd Python-3.8.9/ && sudo ./configure --enable-optimizations && sudo make altinstall"
      }
      SETTINGS
    }
  }

  depends_on = [module.network, module.common_infrastructure]
}


module "vm_secondary" {
  source = "./modules/compute"

  resource_group_name = module.common_infrastructure.created_resource_group_name
  location            = var.location
  vm_name             = "vm-secondary-0"
  public_key          = var.ssh_key
  sid_username        = "oracle"
  vm_sku              = var.vm_sku

  vm_source_image_reference     = var.vm_source_image_reference
  aad_system_assigned_identity  = true
  public_ip_address_resource_id = module.network.db_server_puplic_ip_resources[1].id

  is_diagnostic_settings_enabled = module.common_infrastructure.is_diagnostic_settings_enabled
  diagnostic_target              = module.common_infrastructure.diagnostic_target
  storage_account_id             = module.common_infrastructure.target_storage_account_id
  storage_account_sas_token      = module.common_infrastructure.target_storage_account_sas
  log_analytics_workspace = module.common_infrastructure.log_analytics_workspace != null ? {
    id   = module.common_infrastructure.log_analytics_workspace.id
    name = module.common_infrastructure.log_analytics_workspace.name
  } : null
  data_collection_rules          = module.common_infrastructure.data_collection_rules
  eventhub_authorization_rule_id = module.common_infrastructure.eventhub_authorization_rule_id
  partner_solution_id            = module.common_infrastructure.partner_solution_id
  tags                           = module.common_infrastructure.tags
  db_subnet                      = module.network.db_subnet



  vm_os_disk = {
    name                   = "osdisk-secondary"
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = null
    disk_size_gb           = 128
  }

  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name       = "Virtual Machine Contributor"
      principal_id                     = data.azurerm_client_config.current.object_id
      skip_service_principal_aad_check = false
    }
  }

  vm_extensions = {
    azure_monitor_agent = {
      name                       = "vm-secondary-azure-monitor-agent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorLinuxAgent"
      type_handler_version       = "1.1"
      auto_upgrade_minor_version = true
      automatic_upgrade_enabled  = true
      settings                   = null
    },
    custom_script_extension_linux = {
      name = "CustomScriptExtension"
      publisher = "Microsoft.Azure.Extensions"
      type = "CustomScript"
      type_handler_version = "2.0"
      settings =<<SETTINGS
      {
        "commandToExecute": "sudo yum install -y gcc openssl-devel libffi-devel bzip2-devel wget && cd /opt && sudo wget https://www.python.org/ftp/python/3.8.9/Python-3.8.9.tgz && sudo tar xzvf Python-3.8.9.tgz && cd Python-3.8.9/ && sudo ./configure --enable-optimizations && sudo make altinstall"
      }
      SETTINGS
    }
  }
  #ToDo: Pending
  # role_assignments_nic = {
  #   role_assignment_1 = {
  #     role_definition_id_or_name       = "Contributor"
  #     principal_id                     = data.azurerm_client_config.current.object_id
  #     skip_service_principal_aad_check = false
  #   }
  # }

  depends_on = [module.network, module.common_infrastructure]
}

module "network" {
  source = "./modules/network"

  resource_group                 = module.common_infrastructure.resource_group
  is_data_guard                  = module.common_infrastructure.is_data_guard
  is_diagnostic_settings_enabled = module.common_infrastructure.is_diagnostic_settings_enabled
  diagnostic_target              = module.common_infrastructure.diagnostic_target
  storage_account_id             = module.common_infrastructure.target_storage_account_id
  log_analytics_workspace_id     = try(module.common_infrastructure.log_analytics_workspace.id, "")
  eventhub_authorization_rule_id = module.common_infrastructure.eventhub_authorization_rule_id
  partner_solution_id            = module.common_infrastructure.partner_solution_id
  tags                           = module.common_infrastructure.tags


  #ToDo: role_assignments_nic
  # role_assignments_nic = {
  #   role_assignment_1 = {
  #     name                             = "Contributor"
  #     skip_service_principal_aad_check = false
  #   }
  # }

  role_assignments_pip = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_nsg = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_vnet = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }

  role_assignments_subnet = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }
}


module "storage_primary" {
  source = "./modules/storage"

  resource_group = module.common_infrastructure.resource_group
  is_data_guard  = module.common_infrastructure.is_data_guard
  naming         = "oracle-primary"
  vm             = module.vm_primary.vm
  tags           = module.common_infrastructure.tags
  database_disks_options = {
    data_disks = var.database_disks_options.data_disks
    asm_disks  = var.database_disks_options.asm_disks
    redo_disks = var.database_disks_options.redo_disks
  }
  availability_zone = module.vm_primary.availability_zone

  role_assignments = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }
}

module "storage_secondary" {
  source = "./modules/storage"

  resource_group = module.common_infrastructure.resource_group
  is_data_guard  = module.common_infrastructure.is_data_guard
  naming         = "oracle-secondary"
  vm             = module.vm_secondary.vm
  tags           = module.common_infrastructure.tags
  database_disks_options = {
    data_disks = var.database_disks_options.data_disks
    asm_disks  = var.database_disks_options.asm_disks
    redo_disks = var.database_disks_options.redo_disks
  }
  availability_zone = module.vm_secondary.availability_zone

  role_assignments = {
    role_assignment_1 = {
      name                             = "Contributor"
      skip_service_principal_aad_check = false
    }
  }
}


