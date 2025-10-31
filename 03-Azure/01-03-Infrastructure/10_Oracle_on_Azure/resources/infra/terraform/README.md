# Oracle on Azure - Terraform Configuration

This directory contains Terraform configurations to deploying Oracle Database@Azure (ODAA) infrastructure for the Oracle Microhack.


## Prerequisites

Expection is that you are running on Windows OS.

### 1. Install Required Tools

```powershell
# Install Terraform
winget install Hashicorp.Terraform
# Install Azure CLI (if not already installed)
winget install Microsoft.AzureCLI
```

### 2. Azure Authentication

```powershell
# Login to Azure
az login
# Set the subscription (if you have multiple)
az account set --subscription "your-subscription-id"
```

### 3. Register Required Resource Providers

Based on [Microsoft Learn ODAA Advanced network features](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan#advanced-network-features)

We need to register the Oracle SDN appliance feature for both the Microsoft.Baremetal and Microsoft.Network resource providers to enable Oracle Database@Azure (ODAA) Advanced Network features.

### Manual Registration Steps

~~~powershell
# Register the Oracle SDN appliance feature for Microsoft.Baremetal
az feature register --namespace Microsoft.Baremetal --name EnableRotterdamSdnApplianceForOracle
# Register the Oracle SDN appliance feature for Microsoft.Network
az feature register --namespace Microsoft.Network --name EnableRotterdamSdnApplianceForOracle
# Check registration status for Microsoft.Baremetal
az feature show --namespace Microsoft.Baremetal --name EnableRotterdamSdnApplianceForOracle
# Check registration status for Microsoft.Network
az feature show --namespace Microsoft.Network --name EnableRotterdamSdnApplianceForOracle
# After the features are registered (status shows as "Registered"), you may need to re-register the resource providers:
# Re-register the providers after feature registration
az provider register --namespace Microsoft.Baremetal
az provider register --namespace Microsoft.Network
~~~

> Why Re-register Resource Providers?
> When you register a preview feature, you're essentially enabling a feature flag for your subscription. However, the resource provider itself may not immediately "know" about this new capability until it's refreshed.

### Scripted Registration for Multiple Subscriptions

~~~powershell
# Run the PowerShell script to register the Oracle SDN appliance feature across multiple subscriptions
# Ensure the subscription IDs are correctly set in the script before running
pwsh ./scripts/register-oracle-sdn.ps1
~~~

Output will look as follows:

~~~powershell
=== Processing subscription 556f9b63-ebc9-4c7e-8437-9a05aa8cdb25 ===
Registering feature Microsoft.Baremetal/EnableRotterdamSdnApplianceForOracle...
Registering feature Microsoft.Network/EnableRotterdamSdnApplianceForOracle...
Waiting for feature registration to complete...
  Microsoft.Baremetal/EnableRotterdamSdnApplianceForOracle: Registered; Microsoft.Network/EnableRotterdamSdnApplianceForOracle: Registered
Re-registering provider Microsoft.Baremetal...
Re-registering provider Microsoft.Network...
Completed feature setup for 556f9b63-ebc9-4c7e-8437-9a05aa8cdb25
~~~



## Configuration

### 2. Required Variables

Update `terraform.tfvars` with your values:

## Deployment

```powershell
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

## Post-Deployment


### 2. Connect to AKS Cluster

```powershell
# Get AKS credentials (user must be in deployment group)
az aks get-credentials --resource-group <aks-resource-group> --name <aks-cluster-name>

# Verify connection
kubectl get nodes
kubectl auth can-i "*" "*" --all-namespaces
```

## Troubleshooting

### Common Issues

1. **Oracle.Database provider not registered**
   ```powershell
   az provider register --namespace Oracle.Database
   ```

2. **Insufficient permissions**
   - Ensure you have Contributor or higher permissionstf f
   - Ensure you can register resource providers

3. **AKS node provisioning issues**
   - Check regional availability for the specified VM size
   - Verify subnet CIDR doesn't conflict with existing networks

### Cleanup

To destroy all resources:

```powershell
terraform destroy -auto-approve
```


## Security Considerations

- The `adb_admin_password` is marked as sensitive
- Store the `terraform.tfvars` file securely and don't commit it to version control
- Consider using Azure Key Vault for sensitive values
- Review and adjust network security groups as needed
- Terraform writes generated Entra ID user credentials to `user_credentials.json` in this directory by default; treat this file as sensitive and delete or secure it after use. Override the location with `user_credentials_output_path` or set `disable_user_credentials_export = true` in `terraform.tfvars` to opt out.


## Terraform Entra ID Group Issues

In case you need to clean up Entra ID groups created for AKS deployment access, you can use the following PowerShell script instead of Terraform. But this should be only the last resort. You should be able to manage the groups via Terraform state commands.

~~~powershell
# PowerShell script to delete Entra ID groups created for AKS deployment access
pwsh ./scripts/cleanup-entra-groups.ps1
~~~

Output will look as follows:

~~~powershell
Processing group 'mhteam-0' (b2197001-73a7-4a11-a1e2-703f8813ad26)...
Deleted group 'mhteam-0'.
~~~

## ODAA Advanced Network Features


## Entra ID Conditional Access Policy

The currently used Entra Tenant does include a Conditional Accecss Policy

~~~powershell
az rest --method GET `
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/a0f65b12-2cae-4633-a556-52fef38ed590" `
  --query "{displayName:displayName,state:state,conditions:conditions,grantControls:grantControls,sessionControls:sessionControls}"
~~~

~~~json
{
  "conditions": {
    "applications": {
      "applicationFilter": null,
      "excludeApplications": [],
      "includeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "includeUserActions": [
        "urn:user:registersecurityinfo"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "devices": null,
    "insiderRiskLevels": null,
    "locations": {
      "excludeLocations": [
        "0df1941c-38b1-479b-a57b-7b37916902d0"
      ],
      "includeLocations": [
        "All"
      ]
    },
    "platforms": null,
    "servicePrincipalRiskLevels": [],
    "signInRiskLevels": [],
    "userRiskLevels": [],
    "users": {
      "excludeGroups": [
        "f217541c-b1c0-4247-99d6-c4f06c2492ac"
      ],
      "excludeGuestsOrExternalUsers": null,
      "excludeRoles": [],
      "excludeUsers": [
        "7b368f5d-0186-4650-9d50-3559567906f0",
        "7a4c09e1-dfff-4536-a2c1-f9545e8bdc50"
      ],
      "includeGroups": [],
      "includeGuestsOrExternalUsers": null,
      "includeRoles": [],
      "includeUsers": [
        "All"
      ]
    }
  },
  "displayName": "Security info registration for Microsoft partners and vendors",
  "grantControls": {
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('a0f65b12-2cae-4633-a556-52fef38ed590')/grantControls/authenticationStrength/$entity",
    "builtInControls": [
      "block"
    ],
    "customAuthenticationFactors": [],
    "operator": "OR",
    "termsOfUse": []
  },
  "sessionControls": null,
  "state": "enabled"
}
~~~