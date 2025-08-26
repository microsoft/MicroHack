# Custom Policy: Allowed Regions

This folder contains a custom Azure Policy that restricts resource deployments to a specified list of Azure regions. The policy definition and assignment are split so they can be deployed separately or together via the provided script.

## Files

| File                        | Purpose                                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------------------ |
| `policyDefinition.bicep`    | Creates (or updates) the custom policy definition at subscription scope (parameter schema only). |
| `policyAssignment.bicep`    | Assigns the existing policy definition to a specified resource group.                            |
| `deploy-allowed-regions.sh` | Convenience script to deploy the definition and then the assignment using the Azure CLI.         |

## Parameters

### Definition (`policyDefinition.bicep`)

| Name                   | Type   | Description                                                   |
| ---------------------- | ------ | ------------------------------------------------------------- |
| `policyDefinitionName` | string | Name of policy definition (default `custom-allowed-regions`). |
| `displayName`          | string | Display name.                                                 |
| `policyDescription`    | string | Description.                                                  |

### Assignment (`policyAssignment.bicep`)

| Name                      | Type   | Description                                                         |
| ------------------------- | ------ | ------------------------------------------------------------------- |
| `assignmentName`          | string | Name of the policy assignment.                                      |
| `displayName`             | string | Display name.                                                       |
| `description`             | string | Description.                                                        |
| `policyDefinitionName`    | string | Existing policy definition name.                                    |
| `targetResourceGroupName` | string | Resource group to scope the assignment to.                          |
| `allowedLocations`        | array  | Same array of locations passed through to the definition parameter. |
| `enforcementMode`         | string | `Default` or `DoNotEnforce` (default `Default`).                    |

## Manual Deploy (Bicep via Azure CLI)

Deploy definition (no region values needed at definition time):

```bash

az deployment sub create \
  --name allowedRegionsDef \
  --location $LOCATION$ \
  --template-file policyDefinition.bicep \
  --parameters policyDefinitionName=custom-allowed-regions
```

Deploy assignment:

```bash
az deployment sub create \
  --name allowedRegionsAssign \
  --location "LOCATION" \
  --template-file policyAssignment.bicep \
  --parameters assignmentName=custom-allowed-regions-assignment \
               policyDefinitionName=custom-allowed-regions \
               targetResourceGroupName=MyWorkloadRG \
               allowedLocations='["eastus","westeurope"]'
```

## Validate

List the assignment:

```bash
az policy assignment list --query "[?name=='custom-allowed-regions-assignment']"
```

Summarize policy state for the resource group:

```bash
az policy state summarize --resource-group MyWorkloadRG
```

## Clean Up

```bash
az policy assignment delete --name custom-allowed-regions-assignment --resource-group MyWorkloadRG
az policy definition delete --name custom-allowed-regions
```

## Notes

- The definition is idempotent; redeploying updates it.
- Assignment can be updated by redeploying with modified parameters.
- Use `DoNotEnforce` during rollout/testing to audit before enforcement.
