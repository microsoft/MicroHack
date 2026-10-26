# Adaptive Apps Console automation

**Microsoft-hosted, dedicated lab subscriptions only.** Shared setup assigns a
subscription-wide policy initiative applying `SecurityControl=Ignore` and
`CostControl=Ignore` to resources and resource groups. These hooks are **not BYOS
preparation scripts** and must not run against production, customer, or shared
organizational subscriptions. BYOS participants follow the manual workshop path.

## Provisioning boundary

The active Console path is the **platform-engineer scenario**: it supplies the
**Challenge 02 infrastructure only**. Participants complete
Challenge 01 workstation setup, connect using [Console setup](../docs/console-setup.md),
validate and explore the supplied platforms, then perform Challenges **03-05**:

- Install Radius on AKS and K3s, with their own workspaces and environments.
- Create the Radius managed identity and federated credentials in Challenge 03.
- Install the capability portfolio and register resource types in Challenge 04.
- Publish and register recipes in Challenge 05.

Console does **not** install Radius, Contour, capability portfolios, types or
recipes; create Radius identities, credentials or workspaces; or deploy the
Challenge 06 application. It never uses the worker's Kubernetes context or
in-cluster service account. No Radius, Helm, kubectl, jq, source downloads, or
participant checkout is needed on the worker.

The [Console contract](../../../../99-MicroHack-Template/labautomation/README.md)
supplies authenticated Az PowerShell and Azure CLI, subscription Owner for the
deployment identity, participant object IDs, and a precreated participant RG.
Participants have Owner on that RG. The hooks grant Reader on the AKS node RG for
the later recipe's egress discovery; no subscription-wide participant role or
tenant/Graph permissions are granted. Hosted participants use a resource-group
scoped managed identity rather than creating an Entra application.

The worker requires Linux, PowerShell 7, Az.Accounts/Az.Resources/Az.Network,
Azure CLI with AKS Run Command support, a Bicep compiler usable by Az deployments,
and `chmod`. VM Run Command installs K3s on the guest using its outbound NAT.
The worker needs Azure API access; the VM and clusters need access to their
installation and container image endpoints. Console can mount just this
`labautomation/` folder read-only; no sibling source folders or bootstrap pin
manifest are needed.

## Retained developer-scenario bootstrap

Full-bootstrap artifacts are retained in their original locations for possible
future **application-developer scenario** support. They are not invoked by the
active Console hook, and there is no enabled or validated full-bootstrap toggle.
Keeping the artifacts does not change the platform-engineer handoff above.

- [Bootstrap phases](../resources/bootstrap-console.sh) retain Radius installation,
  resource-type setup, recipe publishing and verification.
- [Tool installer](../resources/install-console-tools.sh) and
  [PowerShell helpers](console-helpers.ps1) retain the private tool/jq installation,
  token-refresh wrapper, allowlisted source downloads and SHA-256 verification.
- [Session helpers](../resources/console-session.sh), the individual Radius/type/
  recipe scripts, and [IaC sources](../iac/) remain available without duplicate copies.
- [Source manifest](bootstrap-source.json) and [pin updater](update-bootstrap-source.ps1)
  retain the previous immutable published snapshot. The pin is historical:
  participant connection changes mean it no longer matches all current sources.
  `update-bootstrap-source.ps1 -Check` reports that drift; the active hook does
  not read or validate this unused manifest.

Before enabling full bootstrapping, scenario owners must agree on the exercise
boundary, wire an explicit scenario selection and developer-ready handoff,
publish and re-pin the intended sources, and validate the complete flow in the
Console. In particular, resolve the observed Radius installation using the
worker's `jobrunner-sa` identity by ensuring the intended lab cluster context and
credentials are used. Retaining these scripts does not resolve that failure.
Worker tool setup, isolated HOME/kubeconfig, token refresh, parallel-job tunnel
isolation, and full Radius/type/recipe readiness must be included in that work.

## Shared setup

Defaults remain **five labs per subscription**, with **Spain Central** first and
**Sweden Central** as fallback (`spaincentral,swedencentral`). Organizers can
override the ordered regions before provisioning.

`shared-deploy-lab.ps1` runs once per subscription:

1. Verify both authenticated contexts target the supplied subscription.
2. Register `Microsoft.Network/AllowBringYourOwnPublicIpAddress`, as also required
   by LocalBox in these hosted subscriptions. Wait up to 15 minutes for
   `Registered`; pending approval, failure or timeout blocks participant jobs.
   Re-register Microsoft.Network afterward so the feature takes effect.
3. Register and wait for Compute, Network, ContainerService, ContainerRegistry,
   ManagedIdentity, DBforPostgreSQL, OperationalInsights, PolicyInsights, Sql,
   KeyVault and Storage.
4. Check each candidate's `Standard_D4s_v5` exposure and **16 free vCPUs per lab**
   in both regional and DSv5-family quota: 12 baseline plus 4 for AKS surge.
   Five labs require 80 free vCPUs (60 steady-state). The check budgets the entire
   fan-out as new capacity, including on reruns.
5. Check PostgreSQL 16 / General Purpose `Standard_D4ds_v5` availability for the later
   participant application (`size: 'L'`, 4 vCores, 16 GiB RAM); this does not provision
   a database or guarantee allocation capacity.
6. Apply the hosted tag initiative and verify inheritance with a temporary RG/NSG.
7. Persist eligible regions and lab count as subscription tags.

Preflight fails if no candidate passes. **SKU and quota checks do not reserve
capacity or guarantee region eligibility.** Other recipe sizes need their own
availability checks. Shared setup does not request quota increases.

## Infrastructure and readiness

`main.bicep` supplies:

| Resource | Configuration |
| --- | --- |
| `aks-adaptive-apps` | Two D4s v5 Ubuntu nodes, OIDC/workload identity, managed Istio, free control-plane tier, one surge node and standard load-balancer egress |
| `vm-adaptive-apps-k3s` | Private D4s v5 Ubuntu 22.04 VM, 64-GiB Standard SSD, K3s |
| `vnet-adaptive-apps` | K3s subnet `10.42.0.0/24`, Bastion subnet `10.42.1.0/26` |
| `bas-adaptive-apps` | Standard Bastion, native tunneling, two scale units, static Standard public IP |
| `natgw-adaptive-apps` | Explicit outbound connectivity through a static Standard public IP |
| `nsg-adaptive-apps-k3s` | Inbound SSH/API restricted to the Bastion subnet |
| `acad<stable hash>` | Unique Standard ACR, anonymous recipe pull enabled, admin credentials disabled; no recipes published |

K3s uses pod/service CIDRs `10.52.0.0/16` and `10.53.0.0/16`, avoiding the
VNet range. Run Command starts an existing K3s installation rather than wiping it.
The VM password uses `New-MhhStablePassword`, so reruns do not silently rotate it.
It is never returned to participants; kubeconfig retrieval uses VM Run Command
and Kubernetes API access uses Bastion.

The hook passes the password through a temporary ARM parameter file in a private
`0700` directory, with file permissions `0600`, rather than a `SecureString`
inside command arguments. The file is removed as soon as deployment returns or
throws, and scratch is removed in `finally`. Bicep retains `@secure()`. No password,
kubeconfig, token or Kubernetes private key is emitted. The worker's HOME, PATH,
KUBECONFIG and isolated `AZURE_CONFIG_DIR` are not changed.

After deployment and node-RG Reader assignments, readiness checks require:

- K3s API and nodes ready, verified inside the VM by Run Command.
- AKS nodes ready, verified by `az aks command invoke` against the named lab AKS
  cluster, with both successful operation state and exit code zero. This uses
  AKS's temporary command pod, not a local worker kubeconfig.
- Bastion provisioned with Standard/Premium SKU and native tunneling enabled.
- ACR provisioned with anonymous pull enabled.

The hook clears `adaptiveAppsInfrastructureReady` before changes and sets it
to `true` only after all checks pass. `adaptiveAppsAcr` records the registry name.
The obsolete developer-ready tag `adaptiveAppsReady` is set to `false` so old
connection scripts cannot mistake this for a lab prepared through Challenge 05.
Credentials emitted on success hand participants off to **Challenge 03**.

`resources/connect-console.sh` runs on the participant workstation. It checks
the new readiness tag, obtains fresh credentials, validates both clusters and
the Bastion tunnel, and writes `artifacts/console-env.sh`. It neither invokes
Radius nor requires installed Radius control planes, types or recipes.
Participants must use the updated checkout when reconnecting.

## Fallback and existing labs

For initial provisioning, `Invoke-MhhDeploymentWithRegionFallback` receives only
validated regions. It can **delete the participant RG and all its contents**,
retry in the same region, or recreate it in the next region, restoring participant
Owner access. Initial provisioning is only for dedicated, disposable lab groups.
The parameter file omits `location`; all resources and later database recipes
follow `resourceGroup().location`. The hook re-reads the group after fallback.

After ARM succeeds, `adaptiveAppsPreserve=true` prevents destructive fallback
on subsequent runs, even when K3s or another readiness check failed. Existing
labs with either readiness tag set also receive this persistent guard before
readiness is cleared. Protected labs receive incremental deployment in place;
an unvalidated region stops the hook rather than relocating the lab.

Rerunning this infrastructure-only hook **does not uninstall** Radius or any
participant workloads already present, including partial installs from earlier
Console attempts. Inspect reused labs before starting the exercises. Do not
remove the preservation tag merely to troubleshoot them.

Fallback depends on the Console's error classifier. Versions that classify
`AKSCapacityHeavyUsage` as `UnknownAssumedFatal` will not try the next region;
update the Console classifier or select a working primary region explicitly.
If public-IP creation still reports `AllowBringYourOwnPublicIpAddress`, verify
both feature registration and subsequent Network provider registration completed.

## Costs and cleanup

Budget approximately **US$35 per lab per 24 hours** (US$175/day for five),
before optional exercises and significant traffic. This is a planning allowance,
not a quote; use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/).
VM deallocation does not stop Bastion, NAT, registry or disk charges. Databases
created during later challenges add cost.

Use Console scope cleanup after the event. Verify AKS's managed node RG is
removed and check for orphaned disks/IPs. Shared policy resources and subscription
tags live outside participant RGs and must be removed when releasing the
subscription, but not while another hosted event still uses them.

## Validation

Run offline tests from the repository root:

```bash
bash "03-Azure/01-01-App Innovation/04-adaptive-apps/labautomation/tests/run-offline-tests.sh"
python3 -m unittest discover -s "03-Azure/01-01-App Innovation/04-adaptive-apps/tests" -p test_console_helpers.py
```

The first runner requires PowerShell 7, Pester 5 and Bicep; set `PWSH_COMMAND`,
`BICEP_COMMAND`, or `PESTER_MODULE` for tools outside PATH. The Python tests need
Bash, jq and kubectl and exercise real local kubeconfig operations. Both suites
mock cloud calls. Tests cover feature registration, quota, fallback protection,
read-only packaging, secure parameters and cleanup, infrastructure readiness
failures, and connecting before Radius installation without changing Radius state.

Offline success is not live acceptance. Verify actual allocation, K3s and AKS node
health, participant Bastion access and permissions, then run the participant
Radius/identity/recipe exercises before the event.

## Hosted policy provenance

`hosted-tag-policy.ps1` and `infra/hosted-tag-policy.bicep` are portable local
copies from `03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/labautomation/`
at commit `d3e446889384325605e5db7e4e61ab1ed8af2cfd`. Their functional bodies,
verification, cleanup and existing `sov-hosted-control-tags` /
`sovereign-hosted-control-tags` names are unchanged. Only provenance comments
were added; there is no runtime dependency on the Sovereign MicroHack folder.
