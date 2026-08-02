# Azure Voting App on AKS with AMD SEV-SNP Confidential Computing nodes

`Deploy-VotingAppCC.ps1` builds a randomly-named AKS cluster with the **smallest possible AMD
SEV-SNP confidential computing node pool** (2 nodes, `Standard_DC2as_v5`) and deploys the public
multi-container [Azure Voting App](https://github.com/Azure-Samples/azure-voting-app-redis) sample
to it, exposed via a public LoadBalancer.

The script follows the same conventions as [`vm-samples/BuildRandomCVM.ps1`](../../vm-samples/BuildRandomCVM.ps1):
random 5-letter suffix on the basename, full resource-group tagging (owner, BuiltBy, GitRepo,
description, smoketest), CC SKU + AMD CVM vCPU quota preflight, and an optional `-smoketest` flag
that auto-deletes everything once the front-end is verified.

## What gets created

| Resource | Detail |
|----------|--------|
| Resource group | `<basename><5 random letters>` with full tagging |
| AKS cluster | 1x `Standard_D2as_v6` system pool, Azure CNI, managed identity, Standard tier |
| CC node pool | `ccpool` - 2x `Standard_DC2as_v5` (AMD SEV-SNP), labelled `workload=confidential` |
| Auto-patching | `--auto-upgrade-channel stable` + `--node-os-upgrade-channel NodeImage` |
| Voting app | `azure-vote-back` (Redis) + `azure-vote-front` (Flask) pinned to CC nodes |
| Public ingress | `azure-vote-front` Service of type `LoadBalancer` on port 80 |

The front-end pods are pinned to the CC pool via `nodeSelector: workload=confidential`, so the user-
facing workload actually runs inside AMD SEV-SNP TEEs.

> **Note on the front-end image.** The previously-published image
> `mcr.microsoft.com/azuredocs/azure-vote-front:v1` was removed from MCR. To keep the sample
> self-contained (no ACR / no role assignments / no `--attach-acr` permissions required), the
> script bootstraps the same Flask app at pod startup from the public
> [`Azure-Samples/azure-voting-app-redis`](https://github.com/Azure-Samples/azure-voting-app-redis)
> repo using the public `python:3.9-slim` image. First rollout takes ~2 minutes per pod
> (apt + pip install); subsequent restarts re-bootstrap the same way.

## Auto-patching policy choices

The script reflects the recommended Azure Policies for AKS:

- **`Kubernetes clusters should have auto-upgrade enabled`** &rarr; `--auto-upgrade-channel stable`
- **AKS node OS image auto-upgrade** &rarr; `--node-os-upgrade-channel NodeImage` (weekly node-image
  refresh, no version drift)
- **`Azure Kubernetes Service Clusters should use managed identities`** &rarr; `--enable-managed-identity`
- **Standard tier** for the financially-backed uptime SLA on the API server

These are all GA features and require no preview registrations, so the deployment works first time
in any standard subscription with quota for the AMD CVM family.

## Usage

```powershell
# Smoke test - auto-cleans up after success (10s cancel window)
./Deploy-VotingAppCC.ps1 -subsID <SUB_ID> -basename sgall -smoketest

# Persistent deployment in a non-default region
./Deploy-VotingAppCC.ps1 -subsID <SUB_ID> -basename sgall -region westeurope -description "demo"
```

### Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `-subsID` | _required_ | Target subscription ID |
| `-basename` | _required_ | Lowercase letters / digits only (ACR forbids hyphens). 5 random letters are appended. |
| `-region` | `northeurope` | Must support `Standard_DC2as_v5` |
| `-ccVmSize` | `Standard_DC2as_v5` | Smallest AMD SEV-SNP CVM (2 vCPU / 8 GiB) |
| `-systemVmSize` | `Standard_D2as_v6` | Tiny non-CC system pool |
| `-ccNodeCount` | `2` | Minimum the user requested |
| `-description` | _empty_ | Added as a tag on the resource group |
| `-smoketest` | _off_ | Auto-deletes the resource group after the front-end is verified |
| `-SkipSkuPreflight` | _off_ | Skip SKU/quota check (ARM will validate at deploy time) |

## Prerequisites

- Azure PowerShell (`Az`) and Azure CLI (`az`), both signed in to the same subscription
- `kubectl` on PATH (the script will install it via `az aks install-cli` if missing)
- AMD CVM (`standardDCASv5Family`) vCPU quota of **at least 4** in the chosen region

## Cleanup

If you didn't use `-smoketest`:

```powershell
Remove-AzResourceGroup -Name <basename><5 random letters> -Force
```
