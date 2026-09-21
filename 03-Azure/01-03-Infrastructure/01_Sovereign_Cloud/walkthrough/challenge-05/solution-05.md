# Walkthrough Challenge 5 - Azure Voting App on confidential AKS nodes

**Estimated duration:** 30-45 minutes

## Objective

Deploy and validate the Azure Voting App and runtime attestation UI on the
provided AKS cluster shared with Challenge 7. Console provisions two Ubuntu
AMD SEV-SNP nodes labelled `workload=confidential`. This script deploys only
applications and never creates, scales or deletes the cluster or its pools.

> [!IMPORTANT]
> **Execution environment.** Like Challenge 4, this challenge runs in a **local
> PowerShell 7+ session**, not in Azure Cloud Shell. It requires `kubectl` access
> and Azure CLI signed in locally.

## Prerequisites

- The [general MicroHack prerequisites](../../Readme.md#general-prerequisites).
- PowerShell 7 or later, running locally.
- Azure CLI signed in to the target subscription.
- Contributor access to the attendee resource group.
- A provided AKS cluster and `cvmnodepool` with two Ubuntu `Standard_DC2as_v5/v6` nodes. The four confidential vCPUs are already allocated; application deployment needs no additional free VM quota.
- Permission to retrieve AKS credentials and deploy workloads/public LoadBalancer services in `challenge-05`.
- `kubectl` installed on PATH.

The current confidential AKS capability is GA. The old `aks-preview` extension
and `AzureLinuxCVMPreview` feature registration are not used.

### Sign in and verify

```powershell
az login --tenant '<your-tenant-id>'
az account set --subscription '<your-subscription-id>'
az account show --query "{sub:name, id:id, tenant:tenantId}" --output table
kubectl version --client
```

> [!NOTE]
> Only the Azure CLI sign-in is needed. Console handles SKU/quota checks and
> infrastructure provisioning; the application script does not call Az PowerShell.

### Check for a conflicting `aks-preview` extension

If the `aks-preview` Azure CLI extension is installed - for example from an
earlier AKS lab - it intercepts every `az aks` command. A version that predates
your current Azure CLI fails to load and stops the deployment. This challenge
does not use `aks-preview`.

```powershell
az extension list --output table

# Remove it if listed
az extension remove --name aks-preview

# Confirm 'az aks' works again (an empty list is a valid result)
az aks list --output table
```

> [!NOTE]
> Challenge 5 does not use the Confidential VM Orchestrator enterprise
> application. That identity is required by the customer-managed confidential
> OS disk path demonstrated in Challenge 5.5. See
> [when Confidential VM Orchestrator is required](CVM-ORCHESTRATOR.md).

> [!IMPORTANT]
> This cluster is shared with Challenge 7. Cleanup removes only Challenge 5's
> named applications. Do not delete the cluster or node pools between challenges.

## Task 1: Configure the MicroHack environment

Use a full repository checkout and run from the Challenge 5 walkthrough directory.
Set the **Sovereign Lab AKS Cluster** name from Console's Credentials tab. For
manual delivery, use the shared lab template's `aksClusterName` output.

```powershell
$env:RESOURCE_GROUP = "labuser-xx"
$env:AKS_CLUSTER = "<Sovereign Lab AKS Cluster>"
az aks show --resource-group $env:RESOURCE_GROUP --name $env:AKS_CLUSTER --query '{name:name,location:location,state:provisioningState}' --output table
```

> [!NOTE]
> These are PowerShell environment variables (`$env:` prefix). Alternatively,
> pass `-ResourceGroup` and `-ClusterName`. `-ConfidentialNodePool` defaults to
> `cvmnodepool`. The cluster's actual region is used; Challenge 4's ACI
> `LOCATION=northeurope` does not change the provided AKS cluster's location.

## Task 2: Run the automated deployment

From this walkthrough directory, run:

```powershell
./Deploy-VotingAppCC.ps1 -Deploy
```

The script automatically:

1. Validates the existing cluster and its two-node Ubuntu confidential pool.
2. Retrieves credentials into a temporary kubeconfig with an explicit context, leaving your default context unchanged.
3. Creates/reuses the owned `challenge-05` namespace without Istio injection, separate from Challenge 7's Radius namespaces.
4. Deploys the voting applications and attestation ConfigMap/UI in that namespace.
5. Waits for rollouts and LoadBalancer IP addresses, then removes the temporary kubeconfig.

> [!NOTE]
> **Expect several minutes for application startup.** The cluster already
> exists, but image downloads, package installation and LoadBalancer allocation
> take time. The script retries the
> front-end smoke test up to 30 times, so early "not responding yet" messages
> are expected rather than a failure.

A successful run prints both public URLs. The attestation pod requires privileged
TPM access, so use only the dedicated lab cluster. Namespace separation prevents
naming and cleanup collisions, not a security boundary against privileged pods.

## Task 3: Verify workload placement

```powershell
$context = "challenge-05-$((az account show --query id -o tsv).Trim())-$env:AKS_CLUSTER"
az aks get-credentials --resource-group $env:RESOURCE_GROUP --name $env:AKS_CLUSTER --context $context --overwrite-existing
kubectl --context $context -n challenge-05 get nodes --show-labels
kubectl --context $context -n challenge-05 get pods --output wide
kubectl --context $context -n challenge-05 get deployment azure-vote-front --output jsonpath='{.spec.template.spec.nodeSelector}'
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

The attestation UI names the pod and the confidential node it runs on, then
displays the verified token:

![Runtime attestation UI in a browser showing the pod and node names, the MAA endpoint and nonce, an outer envelope of azurevm with inner TEE sevsnpvm, an azure-compliant-cvm verdict, and the start of the x-ms-isolation-tee claims table](./images/03-aks-attestation-result.png)

> [!NOTE]
> The token has two layers. The **outer** `azurevm` envelope is issued by the
> Azure HCL and carries VM-level claims such as the vTPM PCR quote and Secure
> Boot state. The **inner** `x-ms-isolation-tee` sub-token carries the SEV-SNP
> hardware evidence that MAA verified. Seeing `azurevm` as the outer type is
> expected on AKS confidential nodes - check the inner block for `sevsnpvm`.

The attestation pod reads the node vTPM through `/dev/tpmrm0`, calls MAA, and
renders the signed claims. In production, a relying application should validate
the token signature, issuer, nonce, and required claims before releasing data.

## Troubleshooting

| Message | Cause | Fix |
| --- | --- | --- |
| Expected two ready Ubuntu nodes | The shared pool is outdated or provisioning is incomplete. | Ask the facilitator to align the pool. Do not create another cluster. |
| `ModuleNotFoundError: No module named 'msrestazure'` in a Python traceback during `az aks create` | A stale `aks-preview` CLI extension is intercepting `az aks` commands. This challenge does not need it. | `az extension remove --name aks-preview`, verify with `az aks list -o table`, then re-run. |
| `Azure CLI is not signed in. Run az login.` | No Azure CLI session. | `az login`, then `az account set --subscription <sub-id>`. |
| `<VARIABLE> is not set. Define the MicroHack environment variables...` | Task 1 variables missing, or set with Bash syntax instead of `$env:`. | Re-run the Task 1 block in the current PowerShell session. |
| `Resource group '<name>' was not found.` | `RESOURCE_GROUP` does not match the attendee resource group. | Confirm with `az group show --name $env:RESOURCE_GROUP`. |
| Namespace ownership-label error | `challenge-05` exists without this script's ownership label. | Have the facilitator inspect it; do not delete or relabel unrelated workloads. |
| `az aks get-credentials failed` / `kubectl get nodes failed` | Cluster not reachable or `kubectl` missing. | `az aks install-cli`, then re-run `az aks get-credentials -g $env:RESOURCE_GROUP -n <cluster>`. |
| Rollout or LoadBalancer timeout | Image pull, scheduling, or public IP allocation is slow. | Inspect with the commands below, then re-run `-Deploy`; the script is idempotent for existing resources. |

Check rollout and bootstrap logs:

```powershell
kubectl --context $context -n challenge-05 get pods --output wide
kubectl --context $context -n challenge-05 describe deployment azure-vote-front
kubectl --context $context -n challenge-05 logs deployment/cc-attest --tail=100
```

Region, SKU and quota selection belong to facilitator provisioning. Rerunning
the workload script does not request or consume quota for another cluster.

## Task 5: Clean up

```powershell
./Deploy-VotingAppCC.ps1 -Cleanup
```

Cleanup removes only the three Challenge 5 deployments, three services and
attestation ConfigMap. It retains the namespace, AKS cluster, both node pools,
resource group and all Challenge 7 resources. It refuses an unowned namespace.

> [!IMPORTANT]
> Clean up the applications after Challenge 5 to release their public services.
> Shared nodes continue accruing charges for Challenge 7. Console/the organizer
> removes infrastructure only after the whole event.

## Source alignment

The complete Azure Voting App confidential AKS source is retained as an
unchanged local snapshot under
[`resources/azure-voting-app`](resources/azure-voting-app/README.md). The
top-level deployment script is derived from that source with only the
MicroHack-specific changes listed in [UPSTREAM-SOURCE.md](UPSTREAM-SOURCE.md).
Use the top-level script for this walkthrough; the script inside `resources`
is retained only as the unchanged upstream reference.
