# Terraform Variable Explanations

1. **Common Parameters**

   - [`location`](#location)
   - [`storage_rg_name`](#storage_rg_name)

4. **Storage Parameters**
   - [`sa_name`](#sa_name)
   - [`container_name`](#container_name)
   - [`user_managed_identity`](#user_managed_identity)

### `location`

- **Description:** Defines the Azure location where the resources will be deployed.
- **Type:** String
- **Default Value:** "eastus"

### `storage_rg_name`

- **Description:** The name of the resource group where the storage account will be created
- **Default Value:** ["rg-mh-oracle-bin"]

### `sa_name`

- **Description:** The name of the storage account
- **Default Value:** ["mhorabinstoregwc71438"]

### `container_name`

- **Description:** The name of the blob container where the binaries will be stored
- **Default Value:** ["oracle-bin"]

### `user_managed_identity`

- **Description:** The name for the user managed identity for access to the storage account
- **Default Value:** ["ora-bin-access"]