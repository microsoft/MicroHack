# Manual setup

Use this path outside eligible Console-hosted events. You own the Azure subscription, costs, permissions and cleanup. A personal subscription does not need Console accounts, exported users or a `LabUsers` group.

## Prepare the subscription

Install PowerShell 7, Azure CLI and the Az modules required by each script. Authenticate interactively as an authorized subscription owner. For multi-user workshops, review the scripts before running them:

1. [Register resource providers](subscription-preparations/1-resource-providers.ps1). This existing utility processes all subscriptions visible to its Azure PowerShell account; restrict account access/context appropriately before use.
2. [Check quotas](subscription-preparations/2-vcpu-quotas.ps1), including confidential VM capacity. LocalBox additionally needs 32 available Esv5/Esv6 vCPUs in its selected host region.
3. [Assign multi-user RBAC](subscription-preparations/3-rbac.ps1) and [create participant resource groups](subscription-preparations/4-resource-groups.ps1) only when needed. Review Graph permissions and target group/scope. Do not give students subscription Owner just to operate LocalBox.

## Deploy participant infrastructure

The [Sovereign lab Bicep template](../../labautomation/sovereign-lab.bicep) provisions the shared Challenge 5/7 AKS cluster with two system and two Ubuntu confidential nodes, K3s VM, Bastion and networking. Deploy it with your selected region, a unique `nameSuffix`, a supported `confidentialVmSize`, and a secure `adminPassword` for K3s. No standalone CVM password or attestation provider is required. Do not put passwords in source control or shell history. Retain the successful deployment name and outputs for health testing; provide `aksClusterName` and `confidentialNodePoolName` to participants.

Challenge 4 provisions its own ACI/ACR comparison in North Europe. Challenge 5 consumes the shared cluster in its actual region; its cleanup deletes only applications. See [regional findings, quotas and migration guidance](../../Readme.md#general-prerequisites) before using an existing lab.

For organizers reproducing the full Console workflow locally, follow the [template's local testing instructions](../../../../../99-MicroHack-Template/labautomation/README.md#local-testing), including its helper container and shared preparation before per-lab deployment. The Console hooks are not general standalone deployment scripts.

## Deploy and prepare LocalBox

Run the [manual LocalBox entry point](localbox/deploy-localbox.ps1) from an authenticated organizer machine:

```powershell
./localbox/deploy-localbox.ps1 -ResourceGroupName 'rg-localbox-shared' -Location 'swedencentral'
```

Choose an allowed Azure Local registration region with `-AzureLocalInstanceLocation` when needed. It can differ from the Azure host region. Wait for the nested Azure Local deployment, then connect to `LocalBox-Client` and follow the shared [post-provisioning guide](../localbox/readme.md). Supply an existing Entra security-group object ID for AKS; its intended administrators must be members.

Run the [health checks](../tests/readme.md) before participants begin. Verify scoped participant access and approved Defender for Servers settings using the [manual preparation and readiness reference](../localbox/manual-preparation.md).

## Cleanup

There is no automatic Console teardown in this path. Remove only resource groups and groups you own after use, including shared LocalBox, and verify removal. The [existing bulk cleanup utility](cleanup/1-resource-groups.ps1) scans all accessible subscriptions and deletes every resource group matching its pattern after confirmation. It is intended for controlled multi-user lab subscriptions, not ordinary personal subscriptions or hosted-event lifecycle cleanup. Preview its complete list and never use a broad pattern against unrelated workloads.