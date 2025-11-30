# Identity Management (Terraform)

This folder contains a **separate Terraform configuration** for managing Entra ID users
and group memberships independently from the main infrastructure.

## Design Principles

1. **Create Once** - Users and group memberships are created once and never modified
2. **Password Rotation Only** - After initial creation, only passwords can be rotated
3. **Single Output File** - `user_credentials.json` contains both object IDs and passwords
4. **No Race Conditions** - `ignore_changes = all` prevents Azure AD eventual consistency issues

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  INITIAL DEPLOYMENT (run once)                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. azuread_user - Creates users with initial password          │
│  2. time_sleep - Waits for Azure AD propagation (90s)           │
│  3. azuread_group_member - Adds users to security group         │
│  4. local_file - Exports user_credentials.json                  │
│                                                                 │
│  After this, azuread_user and azuread_group_member have         │
│  ignore_changes = all, so they're never touched again.          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PASSWORD ROTATION (run before each event)                      │
├─────────────────────────────────────────────────────────────────┤
│  1. random_password - Generates new passwords (keeper trigger)  │
│  2. null_resource - Calls `az ad user update --password`        │
│  3. local_file - Updates user_credentials.json                  │
│                                                                 │
│  The azuread_user resource is NOT modified - password update    │
│  happens via Azure CLI local-exec, avoiding race conditions.    │
└─────────────────────────────────────────────────────────────────┘
```

## Output File Format

`user_credentials.json` (single consolidated file):

```json
{
  "generated_at": "2025-11-29T10:00:00Z",
  "password_rotation_trigger": "event-december-2025",
  "microhack_event_name": "mh2025muc",
  "user_count": 20,
  "group": {
    "object_id": "5fbc2654-d343-401a-be86-08327fe66ec2",
    "display_name": "mh-odaa-user-grp"
  },
  "users": {
    "user00": {
      "object_id": "abc12345-...",
      "user_principal_name": "user00@cptazure.org",
      "display_name": "Peter Parker",
      "password": "xK9mNp2qR4"
    },
    "user01": { ... }
  }
}
```

## Workflow

### 1. Initial Setup (Run Once)

```powershell
cd identity
terraform init
terraform apply
```

This creates:
- Users (user00 through userN)
- Group membership in `mh-odaa-user-grp`
- Exports `user_credentials.json`

### 2. Deploy Main Infrastructure

```powershell
cd ..  # Back to main terraform folder
terraform apply -var="use_external_identity=true"
```

The main configuration reads `identity/user_credentials.json` for object IDs.

### 3. Password Rotation (Before Each Event)

```powershell
cd identity
# Update terraform.tfvars: password_rotation_trigger = "event-december-2025"
terraform apply
```

Or use the helper script:
```powershell
.\scripts\rotate-passwords.ps1 -Phase start -EventName "december-workshop"
```

### 4. Revoke Access (After Each Event)

```powershell
.\scripts\rotate-passwords.ps1 -Phase end
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `user_count` | 1 | Number of users to create |
| `tenant_id` | (required) | Azure AD tenant ID |
| `entra_user_principal_domain` | `cptazure.org` | User principal name domain |
| `azuread_propagation_wait_seconds` | 90 | Seconds to wait for AD propagation (first run only) |
| `password_rotation_trigger` | `initial` | Change to rotate passwords |

## Troubleshooting

### First Run Fails with Race Condition

If the initial deployment fails with "Provider produced inconsistent result":

1. **Wait and retry** - Azure AD may need more time
   ```powershell
   terraform apply -var="azuread_propagation_wait_seconds=180"
   ```

2. **Import orphaned resources** - If group member exists but state is inconsistent
   ```powershell
   $userId = (az ad user show --id "user00@cptazure.org" --query id -o tsv)
   $groupId = (az ad group show --group "mh-odaa-user-grp" --query id -o tsv)
   terraform import 'module.entra_id_users.azuread_group_member.aks_deployment_users[\"0\"]' "${groupId}/member/${userId}"
   ```

### Subsequent Runs Should Be Safe

After the first successful run:
- `azuread_user` has `ignore_changes = all` → no modifications
- `azuread_group_member` has `ignore_changes = all` → no modifications
- Password rotation uses `az ad user update` via local-exec → no Terraform state issues

## Security Notes

⚠️ **IMPORTANT**: 
- `user_credentials.json` contains passwords - **do not commit to git!**
- Rotate passwords after each event to revoke participant access
- The `password_rotation_trigger` value is logged - use descriptive names for audit trail

## Related Documentation

- [DEPLOYMENT_GUIDE.md](../docs/DEPLOYMENT_GUIDE.md) - Full deployment instructions
- [RBAC_SUMMARY.md](../docs/RBAC_SUMMARY.md) - RBAC configuration details
