# Adaptive Apps Console automation

**Microsoft-hosted, dedicated lab subscriptions only.** These hooks intentionally
assign a subscription-wide policy initiative that applies `SecurityControl=Ignore`
and `CostControl=Ignore` on new/updated resources and resource groups. They are
**not BYOS preparation scripts** and must not be run against production, customer,
or shared organizational subscriptions. BYOS participants use the manual scripts
under `../resources/` and the preparation documentation instead.

## Organizer contract and readiness

The [Console contract](../../../../99-MicroHack-Template/labautomation/README.md)
supplies authenticated Az PowerShell and Azure CLI sessions, subscription Owner
for the deployment identity, an already-created participant resource group, its
region, and participant object IDs. The participant already has Owner on that
group. There is no interactive login, Graph application/service-principal creation,
confidential computing, Azure Local, or shared participant Kubernetes cluster here.

Default scope: **resourcegroup**, **five labs per subscription**, in **Sweden Central**
(`swedencentral`). Organizers may override the event region before creating lab
scopes; the shared preflight must pass for that subscription and region. Every participant
gets a dedicated two-node AKS cluster and a separate private K3s VM. The organizer
needs a **Linux runner**, PowerShell 7, current Az.Accounts/Az.Resources/Az.Network,
Azure CLI, a Bicep compiler usable by Az deployments, Bash, curl, tar, jq, awk,
sha256sum and standard Linux utilities. The explicit
downloaded `resources/install-console-tools.sh` installs the versioned client toolchain
and Bastion extension before any bootstrap phase. It does not authenticate.
Outbound access to Azure, GitHub, Kubernetes/Helm/K3s release endpoints and
container registries is required, including HTTPS access to
`raw.githubusercontent.com`. Console can publish this automation folder as its
`lab/` folder without sibling workshop source directories. The hook downloads
only the required files from `microsoft/MicroHack`, using the immutable commit
and per-file SHA-256 hashes in `bootstrap-source.json`. No Git installation or
GitHub credential is required.

Successful provisioning prepares **platform state through challenge 05**.
Participants still complete **challenge 01's workstation setup** before connecting:

- AKS with OIDC, workload identity and managed Istio, plus Radius configured with
  the lab-scoped user-assigned managed identity created by the Bash bootstrap.
- K3s installed through VM Run Command, Radius, both Radius workspaces and
  environments, custom resource types and the recipe registries.
- Verification of the bootstrap workloads, types and recipe registrations on both
  clusters; it is not a claim that optional applications have been deployed.

After workstation setup, participants reconnect with the Console credential
command and begin at challenge 06. They do not rerun manual infrastructure
provisioning. Challenge 07 still needs
Entra enterprise-application/SAML permissions, test users and browser callback
access; challenge 09 needs an approved existing Azure OpenAI deployment, quota
and inference-role assignment permission (plus the local Ollama model download).
Challenge 10 needs the host-only GitHub Copilot desktop app/Radius Canvas, a writable
GitHub repository with Actions/packages access, and separately arranged
tenant/federation/Azure permissions for its workflow deployment path.
These are not supplied by the Console baseline; follow each challenge's documented
prerequisites. No GitHub or AI API credentials are provisioned by these hooks.

## Shared stage: service, quota and region checks

`shared-deploy-lab.ps1` runs once per subscription:

1. Verify both authenticated contexts target the supplied subscription.
2. Register and wait for Compute, Network, ContainerService, ContainerRegistry,
   ManagedIdentity, DBforPostgreSQL, OperationalInsights, PolicyInsights, Sql,
   KeyVault and Storage. SQL supports the published SQL recipe; Key Vault and
   Storage preserve the manual challenge 01 subscription prerequisites.
3. Check each candidate region for a subscription-exposed `Standard_D4s_v5`
   without a **Location** restriction, and for available family and total regional
   compute quota. A Zone restriction does not exclude this non-zonal topology.
4. Require **16 free vCPUs per lab**: 8 for the AKS nodes, 4 for the K3s VM and
   4 for one AKS upgrade surge node. Five new labs therefore require **80 free
   vCPUs**, although their steady-state baseline is 60. Both `standardDSv5Family`
   and `cores` are checked after subtracting existing usage. The shared check
   intentionally budgets the entire requested fan-out as new capacity, including
   on reruns; arrange sufficient free quota before repeating it. It does not
   submit quota increases or delete old labs.
5. Check PostgreSQL Flexible Server capabilities for the default recipe's
   PostgreSQL 16 / Burstable `Standard_B1ms`, rejecting offer restrictions.
   Other recipe sizes may require additional regional SKU availability.
6. Assign and actively verify the hosted control-tag initiative with a short-lived
   probe RG and NSG. Both tags must read back as `Ignore`, while the probe's own
   tag must remain intact. The probe RG is removed in `finally`.
7. Merge subscription tags `microhack-adaptive-location`,
   `microhack-adaptive-regions`, and `microhack-adaptive-lab-count` for the
   participant processes. No local shared state file is needed.

**SKU exposure and quota are not a capacity reservation.** Azure allocation,
regional service limits, policy and actual SKU capacity can still fail deployment.
The stage fails explicitly rather than silently choosing a different VM size.
Quota failure messages identify the required capacity and region.

Console creates participant groups in the **first preferred region**. The
PostgreSQL recipe defaults to `resourceGroup().location`, so the shared stage
requires that first region to pass even if an alternative is eligible. The
participant hook deploys everything in the **supplied RG's actual region**, and
rejects any region absent from the shared metadata. To use an alternative,
reconfigure the event location and explicitly recreate empty scopes through
Console; never move resource deployment independently of the RG metadata.
There is no destructive region fallback, automatic RG deletion or AKS recreation.

## Participant infrastructure and execution

`main.bicep` is the ARM infrastructure topology. Files under `../iac/` are Radius
application/recipe artifacts, **not** alternative ARM infrastructure templates.

| Resource | Configuration |
| --- | --- |
| `aks-adaptive-apps` | Two `Standard_D4s_v5` Ubuntu nodes, managed disks, free control plane tier, one-node maximum surge, OIDC/workload identity, managed Istio, standard load-balancer egress |
| `vm-adaptive-apps-k3s` | `Standard_D4s_v5`, Ubuntu 22.04, 64-GiB Standard SSD, no public NIC/IP |
| `vnet-adaptive-apps` | K3s subnet `10.42.0.0/24`, Bastion subnet `10.42.1.0/26` |
| `bas-adaptive-apps` | Standard Bastion with native tunneling, two scale units, static Standard public IP; name matches existing scripts |
| `natgw-adaptive-apps` | Explicit private-subnet outbound via a static Standard public IP |
| `nsg-adaptive-apps-k3s` | Inbound SSH/API only from the Bastion subnet; other inbound traffic denied |
| `acad<stable hash>` | Globally unique ACR name derived from subscription/RG, Standard, anonymous recipe pull, admin credentials disabled |

The K3s pod/service ranges are `10.52.0.0/16` and `10.53.0.0/16`, avoiding the
Azure VNet range. Run Command installs K3s only when absent and waits for API
readiness. An existing installation is started, not wiped/reinstalled. The VM
admin password comes from `New-MhhStablePassword`, so retries do not silently
rotate it. It is never printed or returned to participants: connect uses Run
Command for kubeconfig retrieval and Bastion for the API, not SSH credentials.
Organizer troubleshooting can use Run Command.

The participant hook uses an **incremental deployment**, retaining resources and
failed deployment records for diagnosis. It grants each supplied participant
**Reader on this AKS node RG only**, so the PostgreSQL recipe can discover AKS
egress IPs. Role operations use object IDs and explicitly disable Graph name
resolution. No subscription-wide participant role is added.

Console mounts the source content **read-only**. The hook uses a private,
GUID-named HOME under the worker's writable `[IO.Path]::GetTempPath()` for `.kube`,
`.rad`, `.ssh`, downloaded clients and scratch files; it never creates directories
under the mounted source. The platform's **absolute,
isolated `AZURE_CONFIG_DIR` is preserved**. Before participant provisioning, the
hook downloads the allowlisted `resources/` and `iac/` files into a private working
lab root beneath that HOME and verifies every hash. Downloads have bounded
timeouts and retries. A missing file, network failure or hash mismatch stops the
hook before ARM deployment or Bash execution; it never falls back to `main`.
All six phases reuse the verified files. Generated `artifacts/types.tgz` and
recipe artifacts cannot race with another participant or modify the source
checkout. No credentials or local configuration are downloaded, and all temporary
files are removed on success or failure. There is no root-level Bicep configuration.
A host-assigned ephemeral loopback port
is passed as `K3S_LOCAL_PORT`; tunnel startup still detects a port collision and
fails rather than taking another lab's tunnel. HOME/PATH/environment are restored
and the exact private directory removed in `finally`.

The Bash interface, run from that isolated lab root, is:

```text
bash resources/install-console-tools.sh
bash resources/bootstrap-console.sh aks-radius
bash resources/bootstrap-console.sh k3s-radius
bash resources/bootstrap-console.sh aks-types
bash resources/bootstrap-console.sh k3s-types
bash resources/bootstrap-console.sh recipes
bash resources/bootstrap-console.sh verify
```

Every invocation follows `Update-MhhToken`; every nonzero exit throws. Each
bootstrap phase obtains fresh local context and owns its tunnel cleanup.
`AZURE_SUBSCRIPTION`, `RESOURCE_GROUP`, `REGION`, `AZURE_LOCATION`, `ACR_NAME`,
`AKS_CLUSTER`, `AKS_CLUSTER_NAME`, `AKS_CONTEXT`, `K3S_VM_NAME`, `K3S_CONTEXT`,
`BASTION_NAME`, `K3S_LOCAL_PORT` and isolated K3s paths are supplied explicitly.

The group is marked `adaptiveAppsReady=false` before changes. `adaptiveAppsAcr`
is written after infrastructure exists; **`adaptiveAppsReady=true` is written
only after the verify phase succeeds**. Only then are identifiers and the minimal
connect command emitted as Console `HackboxCredential` hashtables. No kubeconfig,
bearer token, registry password or Kubernetes private key is emitted.

## Rough costs and cleanup

Budget **US$35 per lab per 24 hours**, or about **US$175/day for the default five
labs**, before optional exercises and significant traffic. This is an approximate
pay-as-you-go planning allowance, not a quote:

- Three continuously running D4s v5 VMs: roughly US$14–20/day by region.
- Standard Bastion: roughly US$7–10/day.
- Managed disks, NAT, Standard IPs, load balancer and ACR: roughly US$4–7/day.
- A small PostgreSQL server created during challenge 06 adds roughly US$1–3/day;
  larger sizes, AI models, log ingestion, bandwidth and optional runners add more.

Use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/)
for the event's actual region/offer. Shared recurring infrastructure cost is
effectively zero; the short-lived policy probe costs are negligible. AKS surge
temporarily increases compute cost. VM deallocation does **not** stop Bastion,
NAT, registry or disk charges.

After the event, use Console's scope cleanup to delete the participant RGs.
Deleting AKS normally removes its managed node RG; **verify node RG deletion** and
check for orphaned disks/IPs. The shared policy assignment/definition, its managed
identity and subscription metadata are outside those groups. The organizer must
remove them when releasing a dedicated subscription, but must not remove an
initiative still used by another hosted event. No cleanup hook deletes resources
automatically on deployment failure.

## Maintaining the bootstrap source pin

The workshop's `resources/` and `iac/` are the only editable source copies.
`bootstrap-source.json` contains only a commit identifier and file hashes, not
duplicate code. When bootstrap inputs change, publish them to `microsoft/MicroHack`
first, then update the pin to that published commit:

```powershell
pwsh -File "./03-Azure/01-01-App Innovation/04-adaptive-apps/labautomation/update-bootstrap-source.ps1" -Commit "<full-40-character-commit-sha>"
```

The updater downloads that revision and verifies it matches the local sources
before writing the manifest. Use `-Check` instead of `-Commit` for an offline
local-source/hash check. Tests reject a stale pin, so source edits deliberately
require refreshing the pin before publishing the automation update.

This is a two-step release when source changes are not yet published: first
publish the canonical inputs, then publish the verified manifest update. If an
input file is added, update the allowlist in `Get-AdaptiveBootstrapFiles` as well.
After publishing the automation update, refresh/reimport the content in Console
before retrying. A pin update is unnecessary for documentation-only changes.

## Offline tests and live acceptance

With PowerShell 7, Pester 5 and Bicep installed, from the repository root:

```bash
bash "03-Azure/01-01-App Innovation/04-adaptive-apps/labautomation/tests/run-offline-tests.sh"
```

Set `PWSH_COMMAND`, `BICEP_COMMAND`, or `PESTER_MODULE` to use already-installed
tools outside PATH. The runner confines Pester scratch files to a unique directory
under the current checkout and removes it on exit. Tests mock Azure and Console
commands; they cover quota boundaries, PostgreSQL capability schemas, failure
propagation, packaging, region consistency, token refresh, phase ordering, output
hygiene, a read-only lab-only Console layout with no sibling sources, immutable
source pins, hash mismatches, download failures, private-directory cleanup, and compiled
ARM resource properties. Only the local test runner puts its test scratch beneath
a writable checkout; the production hook uses writable worker scratch instead.

For the companion Bash helper tests, from this `labautomation/` directory:

```bash
python3 -m unittest discover -s ../tests -p test_console_helpers.py
```

These require Python 3, Bash and `kubectl` on PATH. They exercise real local
`kubectl config` operations to verify kubeconfig preservation; Azure, Radius and
Kubernetes network calls are mocked, so no cloud resources are accessed.

**Offline tests are not Azure deployment verification.** Organizer live testing
must still prove policy propagation, actual allocation, managed Istio, K3s
installation/Bastion, image access, Radius identity federation, recipe execution
and participant reconnect/permissions in Console before an event. No live Azure
deployment was performed as part of authoring this automation.

## Hosted policy provenance

`hosted-tag-policy.ps1` and `infra/hosted-tag-policy.bicep` are portable local
copies from `03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/labautomation/`
at commit `d3e446889384325605e5db7e4e61ab1ed8af2cfd`. Their functional bodies,
verification, cleanup and existing `sov-hosted-control-tags` /
`sovereign-hosted-control-tags` names are unchanged. Only provenance comments
were added; there is no runtime dependency on the Sovereign MicroHack folder.
The retained names deliberately reuse an already-present hosted initiative
instead of creating competing assignments.
