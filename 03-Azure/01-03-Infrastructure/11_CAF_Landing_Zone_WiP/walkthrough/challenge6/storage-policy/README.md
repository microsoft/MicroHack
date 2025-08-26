# Storage Policy Assignment: Disallow Public Blob Access

Creates a policy assignment at a target resource group enforcing that storage accounts do not allow public blob access.

## Files

| File                                    | Purpose                                                                       |
| --------------------------------------- | ----------------------------------------------------------------------------- |
| `storageNoPublicAccessAssignment.bicep` | Subscription-scope template assigning built-in policy to RG (module pattern). |
| `storagePolicyRgModule.bicep`           | RG-scope module that actually creates the assignment.                         |
| `deploy-storage-no-public.sh`           | Helper script resolving built-in policy and deploying assignment.             |

## Parameters (subscription template)

| Name                      | Description                                                          |
| ------------------------- | -------------------------------------------------------------------- |
| `assignmentName`          | Policy assignment name.                                              |
| `displayName`             | Friendly display name.                                               |
| `assignmentDescription`   | Description.                                                         |
| `targetResourceGroupName` | Target RG scope.                                                     |
| `policyDefinitionName`    | Built-in policy definition name (GUID). Optional if script resolves. |
| `policyDefinitionId`      | Full resource ID (alternative to name).                              |
| `enforcementMode`         | `Default` or `DoNotEnforce`.                                         |

## Deployment (Script)

```bash
./deploy-storage-no-public.sh -g MyRG
```

Optional flags:

- `-a` assignment name
- `-m` enforcement mode (`Default|DoNotEnforce`)
- `-n` supply built-in definition name GUID directly
- `-i` supply full policy definition resource ID
- `-l` location for subscription deployment (default eastus)

## Manual Deployment

Resolve built-in definition name GUID (example):

```bash
POLICY_NAME=$(az policy definition list --query "[?displayName=='Storage accounts should disallow public blob access'].name | [0]" -o tsv)
az deployment sub create \
  --name storageNoPublicAssign \
  --location eastus \
  --template-file storageNoPublicAccessAssignment.bicep \
  --parameters targetResourceGroupName=MyRG policyDefinitionName=$POLICY_NAME
```

## Verification

```bash
az policy assignment list --resource-group MyRG --query "[?contains(displayName,'Deny storage public blob access')]"
```

## Cleanup

```bash
az policy assignment delete --name enforce-storage-no-public-blob --resource-group MyRG
```

## Notes

If Microsoft updates the built-in policy display name, use `-n` or `-i` to override.
