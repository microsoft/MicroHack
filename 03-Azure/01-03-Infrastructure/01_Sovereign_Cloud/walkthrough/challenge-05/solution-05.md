# Walkthrough Challenge 5 - Azure Voting App on confidential AKS nodes

[Previous walkthrough](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Challenge](../../challenges/challenge-05.md)

**Estimated duration:** 30-45 minutes

## Objective

Use the newer Azure Voting App automation to deploy an AKS cluster with an AMD
SEV-SNP node pool. The script also deploys a runtime attestation UI, allowing
you to verify the node from inside a pod before trusting the workload.

## Prerequisites

- The [general MicroHack prerequisites](../../Readme.md#general-prerequisites).
- PowerShell 7 or later.
- Azure CLI signed in to the target subscription.
- Azure PowerShell (`Az`) signed in to the same subscription.
- Contributor access to the attendee resource group.
- At least 4 available `standardDCASv5Family` vCPUs in the selected region for the default two-node pool.
- Permission to create AKS clusters and public LoadBalancer services.

The current confidential AKS capability is GA. The old `aks-preview` extension
and `AzureLinuxCVMPreview` feature registration are not used.

> [!IMPORTANT]
> The automation creates the AKS cluster in the existing attendee resource
> group. Cleanup deletes the cluster, not the resource group.

## Task 1: Configure the MicroHack environment

Challenge 5 uses the same PowerShell environment variables as Challenge 4. If
the session still contains them, reuse the existing values.

```powershell
$env:RESOURCE_GROUP = "labuser-xx"
$env:ATTENDEE_ID = $env:RESOURCE_GROUP
$env:LOCATION = "northeurope"

# Run only when HASH_SUFFIX is not already set.
$seed = "$($env:ATTENDEE_ID)-$(Get-Random)-$(Get-Random)"
$bytes = [Text.Encoding]::UTF8.GetBytes($seed)
$hash = [Security.Cryptography.MD5]::HashData($bytes)
$env:HASH_SUFFIX = [Convert]::ToHexString($hash).Substring(0, 8).ToLowerInvariant()
```

## Task 2: Run the automated deployment

From this walkthrough directory, run:

```powershell
./Deploy-VotingAppCC.ps1 -Deploy
```

The script automatically:

1. Checks that `Standard_DC2as_v5` is available in `$env:LOCATION`.
2. Creates a managed-identity AKS cluster with stable Kubernetes and node-image upgrades.
3. Adds two `Standard_DC2as_v5` nodes labelled `workload=confidential`.
4. Acquires cluster credentials and deploys the Azure Voting App.
5. Creates the attestation ConfigMap and deploys the runtime attestation UI.
6. Waits for both rollouts and LoadBalancer IP addresses.

Use `-CcNodeCount 1` when the event design calls for a single confidential node
and the reduced resiliency is acceptable. The script prints both public URLs;
it does not open a browser automatically.

## Task 3: Verify workload placement

```powershell
kubectl get nodes --show-labels
kubectl get pods --output wide
kubectl get deployment azure-vote-front --output jsonpath='{.spec.template.spec.nodeSelector}'
```

Confirm that `azure-vote-front` and `cc-attest` run on nodes with the
`workload=confidential` label. The Redis back end may run on the system pool.

## Task 4: Exercise the applications

The script prints both public URLs.

1. Open the Azure Voting App and submit several votes.
2. Open the attestation UI and select **Attest**.
3. Confirm the MAA token reports `sevsnpvm` and `azure-compliant-cvm`.
4. Confirm `x-ms-sevsnpvm-is-debuggable` is `false`.
5. Review the launch measurement and policy hash as cryptographic evidence.

The attestation pod reads the node vTPM through `/dev/tpmrm0`, calls MAA, and
renders the signed claims. In production, a relying application should validate
the token signature, issuer, nonce, and required claims before releasing data.

## Troubleshooting

Check rollout and bootstrap logs:

```powershell
kubectl get pods --output wide
kubectl describe deployment azure-vote-front
kubectl logs deployment/cc-attest --tail=100
```

If the preflight reports unavailable capacity, select a region that supports
`Standard_DC2as_v5` or request AMD confidential VM quota.

## Task 5: Clean up

```powershell
./Deploy-VotingAppCC.ps1 -Cleanup
```

AKS deletion is asynchronous. The attendee resource group and resources from
other challenges are retained.

## Source alignment

The complete Azure Voting App confidential AKS source is retained as an
unchanged local snapshot under
[`resources/azure-voting-app`](resources/azure-voting-app/README.md). The
top-level deployment script is derived from that source with only the
MicroHack-specific changes listed in [UPSTREAM-SOURCE.md](UPSTREAM-SOURCE.md).
Use the top-level script for this walkthrough; the script inside `resources`
is retained only as the unchanged upstream reference.