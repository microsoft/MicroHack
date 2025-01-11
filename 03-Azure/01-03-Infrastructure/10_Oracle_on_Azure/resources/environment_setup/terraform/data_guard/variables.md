# Terraform Variable Explanations

1. **[Common Parameters](#common-parameters)**

   - [`location`](#location)
   - [`resourcegroup_name`](#resourcegroup_name)
   - [`resourcegroup_tags`](#resourcegroup_tags)
   - [`is_diagnostic_settings_enabled`](#is_diagnostic_settings_enabled)
   - [`diagnostic_target`](#diagnostic_target)
   - [`infrastructure`](#infrastructure)

2. **[Virtual Machine Parameters](#virtual-machine-parameters)**

   - [`ssh_key`](#ssh_key)
   - [`vm_sku`](#vm_sku)
   - [`vm_source_image_reference`](#vm_source_image_reference)
   - [`vm_os_disk`](#vm_os_disk)

3. **[Database Parameters](#database-parameters)**
   - [`database`](#database)
   - [`database_disks_options`](#database_disks_options)
   - [`database_db_nic_ips`](#database_db_nic_ips)

### `location`

- **Description:** Defines the Azure location where the resources will be deployed.
- **Type:** String
- **Default Value:** "eastus"

### `resourcegroup_name`

- **Description:** If defined, this variable specifies the name of the resource group into which the resources will be deployed.
- **Default Value:** ""

### `resourcegroup_tags`

- **Description:** Tags to be added to the resource group.
- **Default Value:** {}

### `is_diagnostic_settings_enabled`

- **Description:** Whether diagnostic settings are enabled.
- **Default Value:** false

### `diagnostic_target`

- **Description:** The destination type of the diagnostic settings. Allowed values are "Log_Analytics_Workspace," "Storage_Account," "Event_Hubs," or "Partner_Solutions."
- **Default Value:** "Log_Analytics_Workspace"

### `infrastructure`

- **Description:** Details of the Azure infrastructure to deploy the SAP landscape into.
- **Default Value:** {}

## Virtual Machine Parameters

### `ssh_key`

- **Description:** Value of the SSH public key to be used for the virtual machines.

### `vm_sku`

- **Description:** The SKU of the virtual machine.
- **Default Value:** "Standard_D4s_v3"

### `vm_source_image_reference`

- **Description:** The source image reference of the virtual machine.
- **Default Value:**
  ```hcl
  {
    publisher = "Oracle"
    offer     = "Oracle-Linux"
    sku       = "79-gen2"
    version   = "7.9.36"
  }
  ```

### `vm_os_disk`

- **Description:** Details of the OS disk, including name, caching, storage account type, disk encryption set, and disk size.
- **Default Value:**
  ```hcl
  {
    name                   = "osdisk"
    caching                = "ReadWrite"
    storage_account_type   = "Premium_LRS"
    disk_encryption_set_id = null
    disk_size_gb           = 128
  }
  ```

## Database Parameters

### `database`

- **Description:** Details of the database node, including options such as DHCP, authentication type, and data disks.
- **Default Value:**
  ```hcl
  {
    use_DHCP = true
    authentication = {
      type = "key"
    }
    data_disks = [
      {
        count                     = 1
        caching                   = "ReadOnly"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 0
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      },
      {
        count                     = 1
        caching                   = "None"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 1
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ]
  }
  ```

### `database_disks_options`

- **Description:** Details of the database node's disk options, including data disks, ASM disks, and redo disks.
- **Default Value:**
  ```hcl
  {
    data_disks = [
      {
        count                     = 1
        caching                   = "ReadOnly"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 20
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ],
    asm_disks = [
      {
        count                     = 1
        caching                   = "ReadOnly"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 10
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ]
    redo_disks = [
      {
        count                     = 1
        caching                   = "None"
        create_option             = "Empty"
        disk_size_gb              = 1024
        lun                       = 60
        disk_type                 = "Premium_LRS"
        write_accelerator_enabled = false
      }
    ]
  }
  ```

### `database_db_nic_ips`

- **Description:** If provided, the database tier virtual machines will be configured using the specified IPs.
- **Default Value:** [""]
