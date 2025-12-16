# Shared Storage Account for Cloud Shell

## Configuration

Your Terraform is now configured to use the **shared storage account** `/subscriptions/09808f31-065f-4231-914d-776c2d6bbe34/resourceGroups/odaa/providers/Microsoft.Storage/storageAccounts/odaamh` for all users.

### What Terraform Will Create

✅ **Per-User File Shares** in the shared storage account:
- `cloudshell-user00` (6 GB)
- `cloudshell-user01` (6 GB)
- `cloudshell-user02` (6 GB)
- `cloudshell-user03` (6 GB)
- `cloudshell-user04` (6 GB)

✅ **RBAC Permissions** for each user:
- **Storage Blob Data Contributor** on storage account `odaamh`
- **Storage File Data SMB Share Contributor** on storage account `odaamh`
- **Reader** on resource group `odaa`

### Configuration in terraform.tfvars

```hcl
use_shared_cloudshell_storage          = true
shared_cloudshell_storage_account_id   = "/subscriptions/09808f31-065f-4231-914d-776c2d6bbe34/resourceGroups/odaa/providers/Microsoft.Storage/storageAccounts/odaamh"
shared_cloudshell_storage_account_name = "odaamh"
shared_cloudshell_resource_group_name  = "odaa"
shared_cloudshell_subscription_id      = "09808f31-065f-4231-914d-776c2d6bbe34"
cloudshell_file_share_quota            = 6
```

## Deployment

```bash
# Plan to see what will be created
terraform plan

# Apply to create file shares and RBAC assignments
terraform apply
```

## What Gets Created

```
Storage Account: odaamh (existing - not created)
└── File Shares (NEW):
    ├── cloudshell-user00 (6 GB) → user00 has access
    ├── cloudshell-user01 (6 GB) → user01 has access
    ├── cloudshell-user02 (6 GB) → user02 has access
    ├── cloudshell-user03 (6 GB) → user03 has access
    └── cloudshell-user04 (6 GB) → user04 has access

RBAC Assignments (NEW):
├── user00 → Storage Blob Data Contributor on odaamh
├── user00 → Storage File Data SMB Share Contributor on odaamh
├── user00 → Reader on odaa RG
├── user01 → (same permissions...)
├── user02 → (same permissions...)
├── user03 → (same permissions...)
└── user04 → (same permissions...)
```

## User Setup Instructions

After Terraform deployment, each user should:

1. **Log in to Azure Portal** with their credentials (user00@cptazure.org, etc.)
2. **Click Cloud Shell icon** (>_) in top navigation
3. **Select environment**: Bash or PowerShell
4. **Choose "Show advanced settings"**
5. **Select subscription**: `09808f31-065f-4231-914d-776c2d6bbe34`
6. **Select resource group**: `odaa`
7. **Select storage account**: `odaamh`
8. **Enter file share name**: 
   - user00 enters: `cloudshell-user00`
   - user01 enters: `cloudshell-user01`
   - user02 enters: `cloudshell-user02`
   - user03 enters: `cloudshell-user03`
   - user04 enters: `cloudshell-user04`
9. **Click "Attach storage"**

## View Outputs

After deployment, check the outputs:

```bash
# View shared storage information
terraform output shared_cloudshell_storage

# View setup guide for users
terraform output shared_cloudshell_setup_guide
```

## Security & Isolation

✅ **Each user can only access their own file share** due to RBAC permissions
✅ **Users cannot see or access other users' Cloud Shell files**
✅ **Shared storage account reduces cost** compared to per-user storage accounts
✅ **All users have the same setup experience** (same storage account/RG)

## Cost

**File Shares** (5 users × 6 GB each = 30 GB total):
- Transaction Optimized tier: ~$6.00/month total
- Blob Storage (Cloud Shell state): ~$0.25/month total

**Estimated Total**: ~$6.25/month for all 5 users

Compare to per-user storage accounts: ~$10/month (5 accounts × $2/each)

**Savings**: ~$3.75/month (~38% cost reduction)

## Troubleshooting

### Issue: User can't see storage account in dropdown
**Solution**: User needs Reader permission on the subscription or resource group (already configured via Terraform)

### Issue: "Failed to attach storage" error
**Check**:
- Storage account `odaamh` has public network access enabled
- User has correct RBAC roles (verify with `az role assignment list`)
- File share exists with correct name

### Issue: User selects wrong file share
**Solution**: Each user MUST use their own file share (`cloudshell-userXX`). If they select another user's file share, they won't have access.

## Advanced: Manual File Share Creation

If you need to create file shares manually (without Terraform):

```bash
# Create file shares
az storage share create --account-name odaamh --name cloudshell-user00 --quota 6
az storage share create --account-name odaamh --name cloudshell-user01 --quota 6
az storage share create --account-name odaamh --name cloudshell-user02 --quota 6
az storage share create --account-name odaamh --name cloudshell-user03 --quota 6
az storage share create --account-name odaamh --name cloudshell-user04 --quota 6

# Get user object IDs (from Entra ID)
USER00_ID=$(az ad user show --id user00@cptazure.org --query id -o tsv)
USER01_ID=$(az ad user show --id user01@cptazure.org --query id -o tsv)
# ... etc

# Assign RBAC roles
STORAGE_ID="/subscriptions/09808f31-065f-4231-914d-776c2d6bbe34/resourceGroups/odaa/providers/Microsoft.Storage/storageAccounts/odaamh"

az role assignment create --assignee $USER00_ID --role "Storage Blob Data Contributor" --scope $STORAGE_ID
az role assignment create --assignee $USER00_ID --role "Storage File Data SMB Share Contributor" --scope $STORAGE_ID
# ... repeat for each user
```

## Related Files

- `cloudshell-shared.tf` - Shared storage configuration logic
- `variables.tf` - Cloud Shell variables
- `terraform.tfvars` - Your current configuration
- `terraform.tfvars.cloudshell.example` - Configuration examples

## Next Steps

1. **Review the configuration** in `terraform.tfvars` (already added)
2. **Run `terraform plan`** to preview changes
3. **Run `terraform apply`** to create file shares and RBAC
4. **Distribute setup instructions** to users (from `terraform output shared_cloudshell_setup_guide`)
5. **Test with one user first** before rolling out to all users
