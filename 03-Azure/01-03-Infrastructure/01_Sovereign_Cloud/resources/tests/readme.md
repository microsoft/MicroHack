# Sovereign Cloud Pester checks

There are two kinds of tests: offline mocked script tests, and live health tests against explicitly selected Azure scopes. Live tests do not deploy attendee VMs, install agents, enable paid plans, apply patches or repair failures. They do not replace the [participant VM readiness exercise](../localbox/manual-preparation.md#step-6-test-the-environment).

## Tooling and authentication

Use PowerShell 7, Pester 5.7.1 or later within major version 5, Azure CLI, and `kubectl` for Full checks. Offline tests were exercised with PowerShell 7.4.13 and Pester 5.7.1. Live Windows/Azure validation remains an integration gate; these versions are not a claim that all LocalBox versions were tested.

The runner uses the caller's existing Azure CLI login and never changes it. LocalBox control-plane checks can use its managed identity. Participant-lab checks need an operator authorized for those explicitly listed resource groups; the LocalBox identity is not automatically authorized there. Full LocalBox checks run on LocalBox-Client with a nested-node Windows credential. Do not serialize passwords or tokens in JSON.

Full Kubernetes checks take dedicated kubeconfigs that already authenticate to the intended clusters. For AKS Local, use an Entra group member in a separate CLI profile/session and the [Jumpstart proxy workflow](https://jumpstart.azure.com/azure_jumpstart_localbox/AKS). Keep the proxy/tunnel running throughout testing. For K3s, use its existing private/Bastion access path. Tests never switch the current kubeconfig or retrieve admin credentials automatically.

## Download without cloning

Download [test-sovereign-cloud.ps1](../test-sovereign-cloud.ps1) from the same trusted ref as preparation. The runner's `-DownloadTests` downloads the helper and two suites to a temporary directory; `-GitHubRef` must identify that **same ref**, preferably a commit SHA. Downloaded scripts execute under your privileges, so review and pin them.

```powershell
$ref = 'main'
$base = "https://raw.githubusercontent.com/microsoft/MicroHack/$ref/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources"
Invoke-WebRequest "$base/test-sovereign-cloud.ps1" -OutFile './test-sovereign-cloud.ps1'
./test-sovereign-cloud.ps1 -Scope LocalBox -Mode ControlPlane `
    -LocalBoxManifestPath 'C:\LocalBox\sovereign-localbox.json' -DownloadTests -GitHubRef $ref
```

For a checkout, run the same command without `-DownloadTests`.

## Full LocalBox check

```powershell
$nodeCredential = Get-Credential -Message 'Nested Azure Local Windows administrator'
./test-sovereign-cloud.ps1 -Scope LocalBox -Mode Full `
    -LocalBoxManifestPath 'C:\LocalBox\sovereign-localbox.json' `
    -LocalBoxKubeconfig 'C:\LocalBox\aks-local.kubeconfig' `
    -NodeCredential $nodeCredential -DownloadTests -GitHubRef $ref
```

Checks cover the Client and bootstrap, cluster/Arc bridge/custom location/AKS extension, supporting Azure resources, image download/storage placement, exact network settings, expected AKS topology/admin group, nested-node/storage health and capacity, Kubernetes node readiness and system pods/controllers. Gateway/DNS/HTTPS probes run from a nested node; these do not prove connectivity from a participant VM that has not yet been created.

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
    -Mode Full -AllowGuestRunCommand -DownloadTests -GitHubRef $ref
```

`-AllowGuestRunCommand` permits Azure VM Run Command on the two selected VMs solely to check K3s service state, DNS and HTTPS egress. This transport is an Azure management action and requires scoped Run Command permission even though the guest commands are read-only. It can create transient Run Command execution artifacts. Without consent, that mandatory Full check fails; it is not silently skipped.

Participant checks include VM power/agent state, confidential VM security settings, K3s install and runtime health, Azure AKS/system/confidential pools with OIDC/workload identity/Istio, private networking/NSG/NAT/Bastion configuration and attestation discovery/JWKS. Bastion's interactive user access and an actual confidential-computing attestation exchange remain separate participant smoke tests, not claims made by ARM health queries.

For both paths together, use `-Scope All`, supply the participant inventory and LocalBox manifest/kubeconfig/Windows credential. Use an operator context authorized for all specified scopes, not a newly broadened managed identity.

## Results

- `health-results/health.xml`: NUnit-format Pester test report with failure detail.
- `health-results/health.json`: names/results/counts and a `FullReadiness` flag; no passwords or kubeconfig contents.
- Nonzero exit: a failure, or incomplete Full coverage. Missing credentials/permissions/connectivity is not a healthy result.
- A successful `ControlPlane` run is explicitly partial and never sets `FullReadiness`. Full readiness covers the checks described above, not application functionality or uncreated student resources.

Waits are bounded by `-TimeoutMinutes` per check. Terminal provisioning failures and authorization errors stop promptly. Secure the reports as operational metadata; underlying tool errors in XML may include resource IDs and tenant information. Retest after resolving failures rather than mutating infrastructure from the health suite.

## Offline regression tests

```powershell
Invoke-Pester ./tests/prepare-localbox.tests.ps1 -Output Detailed
```

Run from the resources directory. This suite tests address and group validation, resource reuse/conflicts, partial-state polling/timeouts, destructive-operation guards, and refusal to report incomplete Kubernetes results as full readiness. It needs no Azure login or infrastructure. Do not run the entire tests folder by default: the two `*.health.tests.ps1` suites require runner-supplied data and live access.