# Azure Cloud Shell Storage for Users

This configuration provides **per-user Azure Cloud Shell storage accounts** that can be provisioned via Terraform. Each user gets their own dedicated storage account with a pre-configured file share for Cloud Shell.

## Important: Cloud Shell Limitations

⚠️ **Azure Cloud Shell cannot be fully automated** because it requires **user-interactive first-time setup** in the Azure Portal or CLI. However, we can pre-provision the storage infrastructure that users will select during their first Cloud Shell launch.

## Two Approaches

### Approach 1: Create New Storage Accounts (Recommended)

Pre-provision new storage accounts that users select during Cloud Shell setup.

**Enable in `terraform.tfvars`:**
```hcl
create_cloudshell_storage = true
cloudshell_storage_account_prefix = "csshell"  # Optional: customize prefix
cloudshell_file_share_quota = 6                 # Optional: default is 6 GB
```

**What gets created:**
- ✅ Resource group per user: `rg-cloudshell-user00`, `rg-cloudshell-user01`, etc.
- ✅ Storage account per user: `csshellmh2025muc00xyz` (globally unique)
- ✅ File share per user: `cloudshell-user00`, `cloudshell-user01`, etc.
- ✅ RBAC permissions: Storage Blob Data Contributor, File Data SMB Share Contributor, RG Contributor

**User Setup Process:**
1. User logs into Azure Portal
2. Clicks Cloud Shell icon (>_) in top navigation
3. Selects Bash or PowerShell
4. Chooses "Show advanced settings"
5. Selects "Use existing" resources
6. Picks their pre-created resource group and storage account
7. Enters their pre-created file share name
8. Clicks "Attach storage"

### Approach 2: Use Existing Storage Accounts

Reference storage accounts that already exist (managed outside Terraform).

**Enable in `terraform.tfvars`:**
```hcl
use_existing_cloudshell_storage = true

existing_cloudshell_storage_accounts = {
  "0" = {
    name                = "existingstorageuser00"
    resource_group_name = "existing-rg-user00"
  }
  "1" = {
    name                = "existingstorageuser01"
    resource_group_name = "existing-rg-user01"
  }
  # Add more as needed for each user index
}
```

**What happens:**
- ✅ Terraform references existing storage accounts via data sources
- ✅ No new storage resources are created
- ✅ Outputs provide information about the existing accounts
- ❌ RBAC assignments must be managed separately (not created by Terraform)

## Deployment

### Step 1: Enable Cloud Shell Storage

Edit `terraform.tfvars`:
```hcl
# For NEW storage accounts:
create_cloudshell_storage = true

# OR for EXISTING storage accounts:
use_existing_cloudshell_storage = true
existing_cloudshell_storage_accounts = {
  # ... your existing storage config
}
```

### Step 2: Deploy

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Get Storage Information

```bash
# View Cloud Shell storage details (sensitive output)
terraform output cloudshell_storage

# View setup instructions for users
terraform output cloudshell_setup_guide
```

### Step 4: Distribute Information to Users

After deployment, provide each user with:
- Their storage account name
- Their resource group name
- Their file share name
- Setup instructions (from `cloudshell_setup_guide` output)

## Storage Account Naming

Storage accounts are named with this pattern:
```
{prefix}{event_name}{user_postfix}{random_suffix}
```

Example: `csshellmh2025muc00abc`
- `csshell` = prefix (configurable via `cloudshell_storage_account_prefix`)
- `mh2025muc` = event name (from `microhack_event_name`)
- `00` = user postfix (user00, user01, etc.)
- `abc` = random 3-char suffix (ensures global uniqueness)

Maximum length: 24 characters (Azure limit for storage account names)

## RBAC Permissions

When creating new storage accounts, Terraform automatically grants each user:

| Role | Scope | Purpose |
|------|-------|---------|
| **Storage Blob Data Contributor** | Storage Account | Full access to blobs (Cloud Shell state files) |
| **Storage File Data SMB Share Contributor** | Storage Account | Full access to file share (Cloud Shell home directory) |
| **Contributor** | Resource Group | Manage resources in their Cloud Shell RG |

## Security Considerations

### ✅ Implemented
- HTTPS-only traffic enforced
- TLS 1.2 minimum version
- Per-user isolation (separate storage accounts)
- Per-user RBAC (users only access their own storage)

### ⚠️ Not Implemented (Optional Enhancements)
- **Private Endpoints**: Storage accounts use public endpoints for Cloud Shell access
- **Network Rules**: No IP restrictions by default
- **Soft Delete**: Not configured (can be enabled if needed)

## Cost Considerations

**Storage Account Costs** (per user):
- Storage Account: ~$0.00/month (no charge for account itself)
- File Share (6 GB): ~$1.20/month (Transaction Optimized tier)
- Blob Storage: ~$0.05/GB/month (Cloud Shell state files, typically < 1 GB)

**Estimated Total**: ~$1.50-$2.00 per user per month

## Customization

### Change Storage Account Prefix
```hcl
cloudshell_storage_account_prefix = "myprefix"  # Max 11 chars
```

### Increase File Share Size
```hcl
cloudshell_file_share_quota = 10  # GB (minimum 6)
```

### Change Storage Location
Storage accounts are created in the same location as other user resources (controlled by `location` variable).

## Terraform Outputs

### `cloudshell_storage` (Sensitive)
Contains detailed information for each user:
```json
{
  "user00": {
    "storage_account_name": "csshellmh2025muc00abc",
    "storage_account_id": "/subscriptions/.../storageAccounts/...",
    "resource_group_name": "rg-cloudshell-user00",
    "file_share_name": "cloudshell-user00",
    "location": "francecentral",
    "primary_access_key": "...",
    "connection_string": "...",
    "setup_instructions": "..."
  }
}
```

### `cloudshell_setup_guide`
User-friendly setup instructions with step-by-step guidance.

### `existing_cloudshell_storage` (when using existing accounts)
Information about referenced existing storage accounts.

## Troubleshooting

### Issue: Storage account name too long
**Solution**: Use shorter prefix (max 11 chars) or shorter event name

### Issue: User can't see storage account in dropdown
**Solution**: Verify user has Reader permissions on the resource group

### Issue: "Failed to attach storage"
**Solution**: Check that:
- Storage account has public network access enabled
- User has required RBAC roles
- File share exists and has correct name

### Issue: Want to use existing storage but Terraform tries to create new
**Solution**: Ensure `create_cloudshell_storage = false` and `use_existing_cloudshell_storage = true`

## Advanced: Manual Storage Account Creation

If you prefer to create storage accounts outside Terraform:

### PowerShell Script Example
```powershell
$users = 0..4  # user00 to user04
$location = "francecentral"
$prefix = "csshell"

foreach ($i in $users) {
    $userPostfix = "{0:D2}" -f $i
    $rgName = "rg-cloudshell-user$userPostfix"
    $storageAccountName = "${prefix}mh2025muc$userPostfix$(Get-Random -Maximum 999)"
    $fileShareName = "cloudshell-user$userPostfix"
    
    # Create resource group
    az group create --name $rgName --location $location
    
    # Create storage account
    az storage account create `
        --name $storageAccountName `
        --resource-group $rgName `
        --location $location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --https-only true `
        --min-tls-version TLS1_2
    
    # Create file share
    az storage share create `
        --name $fileShareName `
        --account-name $storageAccountName `
        --quota 6
    
    Write-Host "Created: $storageAccountName in $rgName"
}
```

Then reference in `terraform.tfvars`:
```hcl
use_existing_cloudshell_storage = true
existing_cloudshell_storage_accounts = {
  "0" = { name = "csshellmh2025muc00123", resource_group_name = "rg-cloudshell-user00" }
  "1" = { name = "csshellmh2025muc01456", resource_group_name = "rg-cloudshell-user01" }
  # ... etc
}
```

## Best Practices

1. **Enable Cloud Shell storage for training/workshop scenarios** where users need persistent shell environments
2. **Use existing storage accounts** if you already have a separate storage provisioning process
3. **Document storage account names** in user credentials file (consider extending output to include in credentials JSON)
4. **Test Cloud Shell setup** with one user before rolling out to all users
5. **Consider lifecycle policies** for cleaning up old Cloud Shell files if storage costs become a concern

## Related Files

- `cloudshell-storage.tf` - Main Cloud Shell storage provisioning logic
- `cloudshell-existing.tf` - Data sources for existing storage accounts
- `variables.tf` - Cloud Shell configuration variables
- `terraform.tfvars` - Enable/configure Cloud Shell storage here

## Future Enhancements

Potential improvements (not currently implemented):
- [ ] Private endpoint configuration for storage accounts
- [ ] Network rules to restrict access by IP
- [ ] Soft delete configuration for file shares
- [ ] Azure Policy assignments for storage compliance
- [ ] Automatic Cloud Shell profile customization (bashrc, PS profile)
- [ ] Pre-install common tools in Cloud Shell environment
