# Challenge 7: Storage Account Deployment

Implements the requirement in `req.txt`:

> Create Bicep scripts to deploy an Azure Storage Account with parameters for name, region, and allowing/denying public access.

## Files

| File | Purpose |
|------|---------|
| `storageAccount.bicep` | Resource group scope template deploying StorageV2 account. |
| `storageAccount.parameters.json` | Example parameter file. |
| `deploy-storage.sh` | Helper script for ad-hoc deployment. |
| `req.txt` | Original requirement. |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `storageAccountName` | string | (none) | Globally unique name (3-24 lowercase alphanumeric). |
| `location` | string | RG location | Region. |
| `allowBlobPublicAccess` | bool | false | Enables/disables anonymous blob access. |
| `skuName` | string | Standard_LRS | Replication SKU. |
| `tags` | object | {} | Optional tags. |

## Deploy (Direct)

```bash
az deployment group create \
  --resource-group MyRG \
  --template-file storageAccount.bicep \
  --parameters storageAccountName=mystorageacct001 allowBlobPublicAccess=false
```

## Deploy (Parameter File)

Edit `storageAccount.parameters.json` then:

```bash
az deployment group create \
  --resource-group MyRG \
  --template-file storageAccount.bicep \
  --parameters @storageAccount.parameters.json
```

## Deploy (Script)

```bash
./deploy-storage.sh -g MyRG -n mystorageacct001 -l westeurope -p false -s Standard_LRS -t env=dev;owner=me
```

## Validate

```bash
az storage account show -n mystorageacct001 -g MyRG --query "allowBlobPublicAccess"
```

## Cleanup

```bash
az storage account delete -n mystorageacct001 -g MyRG --yes
```

## Notes

* `allowBlobPublicAccess=false` is recommended baseline.
* Adjust network rules / private endpoints as needed for production.
