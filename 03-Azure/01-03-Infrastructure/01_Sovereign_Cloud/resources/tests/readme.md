# Sovereign Cloud Pester checks

There are two kinds of tests: offline mocked script tests, and live health tests against explicitly selected Azure scopes. Live tests do not deploy attendee VMs, install agents, enable paid plans, apply patches or repair failures. They do not replace the [participant VM readiness exercise](../localbox/manual-preparation.md#step-6-test-the-environment).

## Tooling and authentication

Use PowerShell 7, Pester 5.7.1 or later within major version 5, Azure CLI, and `kubectl` for Full checks. Offline tests were exercised with PowerShell 7.4.13 and Pester 5.7.1. Live Windows/Azure validation remains an integration gate; these versions are not a claim that all LocalBox versions were tested.

The runner uses the caller's existing Azure CLI login and never changes it. LocalBox control-plane checks can use its managed identity. Participant-lab checks need an operator authorized for those explicitly listed resource groups; the LocalBox identity is not automatically authorized there. Full LocalBox checks run on LocalBox-Client with a nested-node Windows credential. Do not serialize passwords or tokens in JSON.

Full Kubernetes checks require kubeconfigs that already authenticate to the intended clusters. LocalBox defaults to `$HOME/.kube/config` (on Windows, `$HOME\.kube\config`), the usual path updated by `az connectedk8s proxy`. An explicit `-LocalBoxKubeconfig` takes precedence; otherwise a `LocalBox.Kubeconfig` value in the inventory is preserved before using the default. The selected file's current context must target `localbox-aks`; do not switch it during testing. For AKS Local, use an Entra group member in a separate CLI profile/session and the [Jumpstart proxy workflow](https://jumpstart.azure.com/azure_jumpstart_localbox/AKS). Keep the proxy/tunnel running throughout testing. For K3s, use its existing private/Bastion access path. Tests never switch the current kubeconfig or retrieve admin credentials automatically.

## Download without cloning

Download [test-sovereign-cloud.ps1](../test-sovereign-cloud.ps1) from the same trusted ref as preparation. `-DownloadTests` defaults to `$true`: every run downloads the helpers and two suites to a temporary directory and prints the repository/ref being used. Internet access is required unless you pass `-DownloadTests:$false` with a complete local checkout. `-GitHubRef` must identify the **same reviewed ref** as the runner, preferably a commit SHA; it defaults to `main`. Downloaded scripts execute under your privileges, so review and pin them. Download failures stop the run rather than silently falling back to other code.

For a fork, also specify `-GitHubRepository 'owner/MicroHack'`. For example, testing this branch uses `-GitHubRepository 'janegilring/MicroHack' -GitHubRef 'sov-cloud-localbox-post-automation'`. The default repository remains `microsoft/MicroHack`.

```powershell
$ref = 'main'
$base = "https://raw.githubusercontent.com/microsoft/MicroHack/$ref/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources"
Invoke-WebRequest "$base/test-sovereign-cloud.ps1" -OutFile './test-sovereign-cloud.ps1'
./test-sovereign-cloud.ps1 -Scope LocalBox -Mode ControlPlane `
    -LocalBoxManifestPath 'C:\LocalBox\sovereign-localbox.json' -GitHubRef $ref
```

For a checkout, pass `-DownloadTests:$false` explicitly to use its local helpers and suites. Omitting the switch now downloads tests.

## Full LocalBox check

Keep a reviewed [prepare-localbox.ps1](../prepare-localbox.ps1) from the same ref beside the runner. The following builds the nested credential locally without printing the installed configuration; use `Get-Credential` instead if that account has been rotated. The health runner still requires the explicit `-NodeCredential` argument.

```powershell
. ./prepare-localbox.ps1
$nodeCredential = Resolve-LocalBoxNodeCredential -Configuration (Import-PowerShellDataFile -LiteralPath $env:LocalBoxConfigFile)
./test-sovereign-cloud.ps1 -Scope LocalBox -Mode Full `
    -LocalBoxManifestPath 'C:\LocalBox\sovereign-localbox.json' `
    -NodeCredential $nodeCredential -GitHubRef $ref
```

  This example uses the default `$HOME/.kube/config`. Use `-LocalBoxKubeconfig 'C:\LocalBox\aks-local.kubeconfig'` for a dedicated file instead. Changing the defaults does not authenticate kubectl or start the Arc proxy.

Checks cover the Client and bootstrap, cluster/Arc bridge/custom location/AKS extension, supporting Azure resources, image download/storage placement, exact network settings, expected AKS topology/admin group, nested-node/storage health and capacity, Kubernetes node readiness and system pods/controllers. Gateway/DNS/HTTPS probes run from a nested node; these do not prove connectivity from a participant VM that has not yet been created.

## Rerun from a local copy

In elevated PowerShell 7 on LocalBox-Client, change to your local resources directory containing the runner, preparation script and `tests` folder. The offline unit suite also requires the sibling `labautomation` folder, including `localbox-credentials.ps1`, from the same checkout; it mocks the Console helpers and makes no live deployment calls. Use the manifest written by preparation (`-ManifestPath`, default `C:\LocalBox\sovereign-localbox.json`) and an existing authenticated kubeconfig. Keep all scripts from the same reviewed revision; do not overwrite unpublished local fixes with an older download.

The commands below retain your existing Azure CLI authentication. Confirm that it has access to the selected lab resources as described in [Tooling and authentication](#tooling-and-authentication).

```powershell
$manifestPath = Read-Host 'Path to the manifest written by prepare-localbox.ps1'
$kubeconfigPath = Read-Host 'Path to your authenticated AKS kubeconfig'
$outputDirectory = Join-Path (Get-Location) 'health-results'
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester .\tests\prepare-localbox.tests.ps1 -Output Detailed

. .\prepare-localbox.ps1
$nodeCredential = Resolve-LocalBoxNodeCredential -Configuration (Import-PowerShellDataFile -LiteralPath $env:LocalBoxConfigFile)
.\test-sovereign-cloud.ps1 -Scope LocalBox -Mode Full `
  -LocalBoxManifestPath $manifestPath `
  -LocalBoxKubeconfig $kubeconfigPath `
  -NodeCredential $nodeCredential -OutputDirectory $outputDirectory -DownloadTests:$false
Get-Content (Join-Path $outputDirectory 'health.json')
```

Use a group-member kubeconfig to exercise Entra-based access. An explicitly supplied cluster-admin certificate can verify Kubernetes runtime health, but **not Entra group-member sign-in**. Restrict kubeconfig file access and never publish its contents. The health suite only reads the supplied credential; it does not create a kubeconfig, retrieve credentials or grant roles.

After an intentional scale operation, the manifest must contain the new expected worker count. Preparation defaults to one control-plane node and three workers. Use `-NodeCount` to override the worker count; preparation does not silently scale an existing cluster whose configuration differs.

## Participant lab inventory

Create a local JSON inventory with one entry for every lab to validate. Use the actual successful `sovereign-lab-*` deployment name, not the subscription-level RBAC deployment name. Paths must resolve on the test machine.

```json
{
  "Labs": [
    {
      "SubscriptionId": "00000000-0000-0000-0000-000000000001",
      "ResourceGroupName": "rg-your-lab",
      "DeploymentName": "sovereign-lab-your-successful-deployment",
      "AksKubeconfig": "C:\\LocalBox\\azure-aks.kubeconfig",
      "K3sKubeconfig": "C:\\LocalBox\\k3s.kubeconfig"
    }
  ]
}
```

For manual deployments without retained deployment records, replace `DeploymentName` with an `Outputs` object containing the plain nonsecret output values from [sovereign-lab.bicep](../../labautomation/sovereign-lab.bicep). Missing required outputs fail. The runner does not treat whatever happens to exist as the expected inventory.

```powershell
./test-sovereign-cloud.ps1 -Scope ParticipantLabs -InventoryPath './inventory.json' `
    -Mode Full -AllowGuestRunCommand -GitHubRef $ref
```

`-AllowGuestRunCommand` permits Azure VM Run Command on the selected K3s VM solely to check K3s service state, DNS and HTTPS egress. This transport is an Azure management action and requires scoped Run Command permission even though the guest commands are read-only. It can create transient Run Command execution artifacts. Without consent, that mandatory Full check fails; it is not silently skipped.

Participant baseline checks cover K3s VM power/agent/install/runtime health, two system and two labeled Ubuntu confidential AKS nodes, OIDC/workload identity/Istio and upgrade settings, and private networking/NSG/NAT/Bastion configuration. They no longer require a standalone CVM or custom attestation provider. Challenge 4 ACI/ACR, Challenge 5 applications, Bastion interactive access and actual signed attestation exchanges are participant smoke tests, not claims made by baseline ARM health checks.

For both paths together, use `-Scope All`, supply the participant inventory and LocalBox manifest/kubeconfig/Windows credential. Use an operator context authorized for all specified scopes, not a newly broadened managed identity.

## Results

- `health-results/health.xml`: NUnit-format Pester test report with failure detail.
- `health-results/health.json`: names/results/counts and a `FullReadiness` flag; no passwords or kubeconfig contents.
- Nonzero exit: a failure, or incomplete Full coverage. Missing credentials/permissions/connectivity is not a healthy result.
- A successful `ControlPlane` run is explicitly partial and never sets `FullReadiness`. Full readiness covers the checks described above, not application functionality or uncreated student resources.

Readiness retries use `-TimeoutMinutes` per check (default 15 minutes). The runner prints each Kubernetes query, then reports the failed condition, attempt number and remaining time before each 15-second retry. Nodes can be Ready while a system pod, Deployment or DaemonSet is not; the same test verifies all of them. Authorization errors stop without retrying.

DaemonSets are checked against their desired scheduling count. Windows-only DaemonSets such as `calico-node-windows` can legitimately report zero desired and zero Ready pods on a Linux-only cluster; that is not a failure. Missing scheduling status or fewer Ready pods than desired still fails. An older runner that reports a zero-target DaemonSet as unavailable needs the corrected runner and downloaded helpers from the same ref, not deletion of the DaemonSet or a longer timeout.

Each kubectl API request uses `--request-timeout=20s`. The readiness deadline is checked between attempts, not as a hard process timeout; an external authentication plugin can take longer or require attention. If the last query stays on screen without retry messages, check the proxy terminal and authentication state. In a separate terminal, inspect the same kubeconfig without changing its context:

```powershell
kubectl --kubeconfig "$HOME/.kube/config" --request-timeout=20s get nodes
kubectl --kubeconfig "$HOME/.kube/config" --request-timeout=20s get pods -A
kubectl --kubeconfig "$HOME/.kube/config" --request-timeout=20s get deployments,daemonsets -n kube-system
```

Use your explicit kubeconfig path instead when testing a dedicated file. Secure the reports as operational metadata; underlying tool errors in XML may include resource IDs and tenant information. Retest after resolving failures rather than mutating infrastructure from the health suite.

## Offline regression tests

```powershell
Invoke-Pester ./tests/prepare-localbox.tests.ps1 -Output Detailed
Invoke-Pester ./tests/shared-aks.tests.ps1 -Output Detailed
```

Run from the resources directory. These suites test LocalBox validation/reconciliation and shared-AKS workload targeting, namespace ownership, cleanup safety, pool compatibility and quota contracts. They need no Azure login or infrastructure. Do not run the entire tests folder by default: the two `*.health.tests.ps1` suites require runner-supplied data and live access.