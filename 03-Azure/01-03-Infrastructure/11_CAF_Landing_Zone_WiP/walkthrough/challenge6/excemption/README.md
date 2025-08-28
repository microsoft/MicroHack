# Policy Exemption Automation (Microhack Challenge 6)

This folder (name kept as `excemption` per challenge materials) contains:

1. `create-exemption.sh` – Bash automation to discover policy assignments under a given scope (subscription or management group) that match a specified **policy** (by GUID, full ID, or display name) and create a policy exemption for each at a target scope (subscription or resource group).
2. `policyExemption.bicep` – Re‑usable Bicep module to declare a single static policy exemption when the assignment ID is already known.
3. `req.txt` – Original requirement list.

## Requirements Mapping

| Requirement (updated)                                | Implemented In                                      | Notes                                                                 |
| ---------------------------------------------------- | --------------------------------------------------- | --------------------------------------------------------------------- |
| use bicep or bash                                    | Both (script + module)                              | Dynamic discovery in Bash; static declaration via Bicep               |
| pass in assignment scope (incl. MG)                  | `--assignment-scope` (script)                       | Supports subscription or management group scopes                      |
| pass in policy name (GUID), full ID, or display name | `--policy` (script)                                 | Accepts GUID, full ID, or display name (case-insensitive exact match) |
| legacy full policy id support                        | `--policy-definition-id` (script)                   | Backwards compatible alias                                            |
| pass in exemption scope                              | `--exemption-scope-type` / `--exemption-scope-name` | Builds full resource ID                                               |
| pass in name of scope                                | `--exemption-scope-name`                            | Used in exemption naming                                              |
| determine assignment id                              | Script queries Azure                                | Filters assignments after retrieval                                   |
| determine exemption scope resource id                | Built from type + name                              | Displays computed ID                                                  |
| create exemption for each assignment                 | Loop in script                                      | Skips if exemption already exists (idempotent)                        |

## Bash Script Usage

```bash
chmod +x create-exemption.sh
./create-exemption.sh \
  --assignment-scope /subscriptions/<subId> \
  --policy <policyGuidOrDisplayNameOrFullId> \
  --exemption-scope-type resourceGroup \
  --exemption-scope-name <rgName> \
  --reason "Approved exception - CAB#1234"
```

Dry run (no changes):

```bash
./create-exemption.sh --assignment-scope /providers/Microsoft.Management/managementGroups/<mgId> \
  --policy "Storage accounts should disable public network access" \
  --exemption-scope-type subscription \
  --exemption-scope-name <subId> \
  --dry-run --verbose
```

### Parameters (Script)

| Flag                     | Description                                         | Required |
| ------------------------ | --------------------------------------------------- | -------- |
| `--assignment-scope`     | Scope to search for policy assignments              | Yes      |
| `--policy`               | Policy GUID, full ID, or display name               | Yes      |
| `--policy-definition-id` | (Legacy) full policy definition ID                  | No       |
| `--exemption-scope-type` | `subscription` or `resourceGroup`                   | Yes      |
| `--exemption-scope-name` | Subscription GUID (if type=subscription) or RG name | Yes      |
| `--exemption-category`   | Waiver (default) or Mitigated                       | No       |
| `--reason`               | Description / justification                         | No       |
| `--dry-run`              | Show actions only                                   | No       |
| `--verbose`              | Debug logging                                       | No       |

### Behavior Notes

- Generates deterministic exemption names (`ex-<scopeName>-<hash>`).
- Skips creation if an exemption with that name already exists at the target scope.
- Supports macOS (`md5`) and Linux (`md5` or falls back to `shasum`).
- Extend `build_exemption_scope_id()` to support management groups or granular resource scopes if required.

## Bicep Module Usage

Deploy a single exemption (example targeting a resource group):

```bicep
// In a parent Bicep file
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: 'my-workload-rg'
}

module exemption './policyExemption.bicep' = {
  name: 'exemptionModule'
  scope: rg
  params: {
    exemptionName: 'ex-my-workload-rg-001'
    displayName: 'Exemption for Policy XYZ'
    policyAssignmentId: '/subscriptions/<subId>/providers/Microsoft.Authorization/policyAssignments/<assignmentName>'
    exemptionCategory: 'Waiver'
    description: 'Approved deviation CAB#1234'
  }
}
```

Deploy with Azure CLI:

```bash
az deployment sub create \
  --name ExemptionDeploy \
  --location <region> \
  --template-file main.bicep
```

## Extending

- Already supports management group assignment scopes (e.g., `/providers/Microsoft.Management/managementGroups/<mgId>`).
- Add selective exemption for policy set references via `policyDefinitionReferenceIds` parameter in the module.
- Introduce expiry handling by adding a `--expires-on` flag to the script (already supported in Bicep via parameter) and mapping through to the CLI with `--expires-on`.

## Troubleshooting

| Issue                    | Cause                    | Fix                                                         |
| ------------------------ | ------------------------ | ----------------------------------------------------------- |
| No assignments found     | Wrong scope or policy ID | Verify `az policy assignment list --scope <scope>` manually |
| Auth error               | Not logged in            | Run `az login`                                              |
| Exemption already exists | Name collision           | Remove existing or adjust naming logic                      |

---

Generated as part of Microhack Challenge 6 automation deliverable.
