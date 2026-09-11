# Lab automation

This folder is **optional**. Delete it if your MicroHack does not need automated
Azure provisioning.

When present, the MicroHack platform reads [lab-defaults.json](lab-defaults.json)
to decide *how* to scope lab environments, and (optionally) invokes
[deploy-lab.ps1](deploy-lab.ps1) once per participant to deploy
MicroHack-specific resources into a pre-provisioned Azure scope. One further
optional script, [shared-deploy-lab.ps1](shared-deploy-lab.ps1), runs once per
subscription *ahead of* that fan-out to lay down whatever the individual labs
build on. See
[Optional hook](#optional-hook-shared-deploy-labps1).

**One deployment fans out into N identical labs, one per participant.** The
platform runs *your one script* many times over, in a separate process each
time, and every run builds the same lab content in its own Azure scope for a
different participant. Nothing is shared between those copies: not the Azure
resources, not the Azure CLI profile, not the OpenTofu state. Write your script
as if it only ever deploys a single lab for a single user,
**because from inside the script, that is exactly what it does.**

## How the platform runs your lab automation

```mermaid
flowchart TD
    A[Deployment start] --> B[Read lab-defaults.json]
    B --> C["Reserve the event's subscriptions"]
    C --> D["Pre-provision each participant's scope<br/>subscription / resource group<br/>+ user RBAC"]
    D --> SH["shared-deploy-lab.ps1 (optional)<br/>once per subscription, in parallel<br/>receives all its participants"]
    SH --> G{"Shared stage<br/>succeeded?"}
    G -- no --> X["No deploy-lab.ps1 runs at all<br/>deployment marked failed"]

    subgraph fan["Fan out: one isolated process per participant, identical content"]
        direction LR
        L1["deploy-lab.ps1<br/>participant 1"]
        L2["deploy-lab.ps1<br/>participant 2"]
        LN["deploy-lab.ps1<br/>participant N"]
    end

    G -- yes --> L1
    G -- yes --> L2
    G -- yes --> LN

    SH -. HackboxCredential for every lab in that subscription .-> CR
    L1 -. HackboxCredential .-> CR
    L2 -. HackboxCredential .-> CR
    LN -. HackboxCredential .-> CR

    CR[(Credential repository<br/>per-lab credentials)] --> DASH[User dashboard]
```

Key points for integration:

- **One process per participant, same content every time:** `deploy-lab.ps1`
  runs in its own PowerShell process, with that participant's `SubscriptionId` /
  `ResourceGroupName` / `AllowedEntraUserIds` already set. Your script never
  loops over participants and never sees more than one; the platform does the
  fan-out for you.
- **Credentials are stored per lab:** every `HackboxCredential` hashtable your
  script writes to the output stream is captured, attributed to the lab the
  job ran for, and surfaced on that lab's personal dashboard. A credential
  emitted by one participant's run can never leak into another's.
- **No cross-lab state:** sibling processes are building the *same* lab for
  *other* participants at the same time, so nothing may be shared between them.
  Each process automatically gets its own isolated Azure CLI login. OpenTofu is
  opt-in: its equally isolated workspace is created the first time your script
  calls
  [`Invoke-MhhTofuCommand`](#invoke-mhhtofucommand). Use `Get-MhhStableHash`
  over `$AllowedEntraUserIds` if you need a deterministic, per-participant
  resource name.
- **Anything that must happen once, not N times, belongs in the shared hook.**
  Resources several labs in one subscription share (a hub network, a central
  workspace, …), and one-off subscription preparation every parallel
  `deploy-lab.ps1` would otherwise race on (registering resource providers, …),
  go into `shared-deploy-lab.ps1`. It is optional and independent of
  `deploy-lab.ps1`, and it always completes before the first lab starts.

- [Lab automation](#lab-automation)
  - [How the platform runs your lab automation](#how-the-platform-runs-your-lab-automation)
  - [Folder layout](#folder-layout)
  - [`lab-defaults.json`](#lab-defaultsjson)
    - [Fields](#fields)
    - [Cost forecasting formula](#cost-forecasting-formula)
    - [`groups`: supported values](#groups-supported-values)
    - [`deploymentType`: what each value means for your script](#deploymenttype-what-each-value-means-for-your-script)
  - [`deploy-lab.ps1`](#deploy-labps1)
    - [Required parameter contract](#required-parameter-contract)
    - [What the platform guarantees before your script runs](#what-the-platform-guarantees-before-your-script-runs)
    - [Keeping credentials alive in long-running scripts](#keeping-credentials-alive-in-long-running-scripts)
    - [Deploying when `deploymentType = subscription`](#deploying-when-deploymenttype--subscription)
    - [Deploying with OpenTofu](#deploying-with-opentofu)
    - [Returning credentials to the user (HackboxCredential)](#returning-credentials-to-the-user-hackboxcredential)
      - [Passwords and re-runs](#passwords-and-re-runs)
    - [Cleaning up](#cleaning-up)
    - [Local testing](#local-testing)
  - [Optional hook: `shared-deploy-lab.ps1`](#optional-hook-shared-deploy-labps1)
    - [Where it fits in the pipeline](#where-it-fits-in-the-pipeline)
    - [Shared hook parameter contract](#shared-hook-parameter-contract)
    - [Rules for the shared hook](#rules-for-the-shared-hook)
    - [Example: a shared hub network](#example-a-shared-hub-network)
    - [Testing the shared hook locally](#testing-the-shared-hook-locally)
  - [Available helper cmdlets](#available-helper-cmdlets)
    - [`New-MhhStablePassword`](#new-mhhstablepassword)
    - [`Get-MhhStableHash`](#get-mhhstablehash)
    - [`Get-MhhLabUser`](#get-mhhlabuser)
    - [`Update-MhhToken`](#update-mhhtoken)
    - [`Invoke-MhhSynchronized`](#invoke-mhhsynchronized)
    - [`Set-MhhManagedIdentityRoleMember`](#set-mhhmanagedidentityrolemember)
    - [`Invoke-MhhTofuCommand`](#invoke-mhhtofucommand)
    - [`Remove-MhhTofuWorkspace`](#remove-mhhtofuworkspace)
    - [`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback)
    - [`Test-MhhDeploymentFailureRetryable`](#test-mhhdeploymentfailureretryable)
    - [`Remove-MhhResourceGroup`](#remove-mhhresourcegroup)
  - [Authoring guidelines](#authoring-guidelines)

## Folder layout

```text
labautomation/
├── lab-defaults.json        # Platform-facing configuration (required if folder exists)
├── shared-deploy-lab.ps1    # Optional: runs once per subscription, before the labs
├── deploy-lab.ps1           # Optional: per-user Azure deployment script
├── main.bicep               # Optional: Bicep/ARM template your script deploys  (Recommended)
└── tofu/                    # Optional: OpenTofu (.tf) module your script deploys (NOT Recommended)
```

`lab-defaults.json`, `deploy-lab.ps1` and `shared-deploy-lab.ps1` are picked up
automatically by file name, no registration step is required. Anything else in
the folder is yours; reference it from your script with
`Join-Path $PSScriptRoot '<name>'`.

## `lab-defaults.json`

This file tells the platform how to size and scope lab environments for your
MicroHack. The schema is published at
`https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/lab-defaults-schema.json`
and is validated when your MicroHack is loaded.

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/lab-defaults-schema.json",
  "groups": [ "GHCPUsers" ],
  "deploymentType": "resourcegroup",
  "labsPerSubscription": 4,
  "preferredLocation": "swedencentral, norwayeast, spaincentral",
  "estimatedDailyCostsUsd": 25.0,
  "estimatedSharedDeploymentDailyCostsUsd": 0.0
}
```

Only include fields you want to set; missing fields fall back to platform defaults.

### Fields

| Field | Type | Description |
| --- | --- | --- |
| `groups` | `string[]` | Group-based feature activations for the Entra ID users created for this lab. See [supported values](#groups-supported-values). |
| `deploymentType` | `"resourcegroup"` \| `"subscription"` \| `"resourcegroup-with-subscriptionowner"` | Azure scope each user receives. See [details](#deploymenttype-what-each-value-means-for-your-script). |
| `labsPerSubscription` | `integer` (1–100) | How many users to pack into a single Azure subscription. Ignored when `deploymentType` is `subscription`. |
| `preferredLocation` | `string` | Comma-separated Azure regions, **in priority order** (e.g. `"swedencentral, norwayeast"`). The first region is used as the default deployment location. List multiple regions so your script can fall back if the first region doesn't support every service your lab needs; see [authoring guidelines](#authoring-guidelines). |
| `estimatedDailyCostsUsd` | `number` (≥ 0) | Estimated daily cost per lab environment in USD. Based on the resources created by `deploy-lab.ps1`. Used for cost forecasting in the lab lifecycle wizard. |
| `estimatedSharedDeploymentDailyCostsUsd` | `number` (≥ 0) | Estimated daily cost in USD of resources created once per subscription by `shared-deploy-lab.ps1`. Cost forecasting multiplies this value by the subscription count: labs divided by `labsPerSubscription`, rounded up, for resource-group deployments; one subscription per lab for `subscription` deployments. Defaults to `0` when absent. |

### Cost forecasting formula

The number of Azure subscriptions required for a deployment is:

```math
\displaystyle \text{subs} =
\begin{cases}
\displaystyle \text{labs} & \text{deploymentType} = \texttt{subscription} \\[4pt]
\left\lceil \dfrac{\text{labs}}{\text{labsPerSubscription}} \right\rceil
& \text{deploymentType} \in \{\texttt{resourcegroup}, \texttt{resourcegroup-with-subscriptionowner}\}
\end{cases}
```

The final estimated cost in USD is:

```math
\displaystyle \text{est} = \text{days} \times \left(
\displaystyle \text{labs} \times
\underbrace{\left(\text{estimatedDailyCostsUsd} + \textstyle\sum \text{groupSurcharge}\right)}_{\text{per-lab}}
+ \text{subs} \times
\underbrace{\text{estimatedSharedDeploymentDailyCostsUsd}}_{\text{per-subscription}}
\right)
```

Here, `labs` is the number of lab environments, `days` is the deployment duration,
and $\sum \text{groupSurcharge}$ represents the license costs for `groups` per lab.
Per-lab costs and group surcharges are multiplied by `labs`; shared deployment costs are multiplied by `subs`
because `shared-deploy-lab.ps1` runs once per subscription.

### `groups`: supported values

Add a group name to provision an extra capability for every lab user created
for this MicroHack:

| Group | What it provisions for each lab user |
| --- | --- |
| `GHCPUsers` | A GitHub Copilot seat assigned to the user. |
| `M365-E5-Users` | A Microsoft 365 E5 license assigned to the user. |

You can combine multiple groups, e.g. `"groups": [ "GHCPUsers", "M365-E5-Users" ]`.
Leave the array empty (`[]`) if your MicroHack needs only Azure.

### `deploymentType`: what each value means for your script

| Value | Azure scope per user | RBAC on subscription | RBAC on resource group |
| --- | --- | --- | --- |
| `resourcegroup` | One resource group, **shared subscription** | `Reader` | `Owner` |
| `resourcegroup-with-subscriptionowner` | One resource group, **shared subscription** | `Owner` | `Owner` |
| `subscription` | One dedicated subscription | `Owner` | n/a |

Choose `subscription` only when your lab genuinely needs subscription-scoped
resources (policies, management-group operations, etc.); it is materially more
expensive in subscription pool consumption.

## `deploy-lab.ps1`

This script is **optional**. If it is missing, or if its parameter block does
not match the contract below, the platform will skip it and only provision the
empty scope (subscription / resource group) plus RBAC.

The platform invokes your script **once per participant**, in parallel, inside a
pre-configured PowerShell environment with that participant's Azure context
already selected. Every invocation gets the same script and the same content but
a different scope, so write it for exactly one lab: the parameters below are
already narrowed to a single participant, and `$AllowedEntraUserIds` always
contains IDs, that require access to the lab.

### Required parameter contract

Your script's param block is **validated before it runs**. If it doesn't match
the contract below, the script is skipped and a warning is written to the job
log; the lab still gets its empty scope and RBAC, but none of your resources.

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)
```

| Parameter | Provided by | Notes |
| --- | --- | --- |
| `DeploymentType` | platform | Same value as in `lab-defaults.json`. |
| `SubscriptionId` | platform | The user's target Azure subscription. `Set-AzContext` is already pointed at it. |
| `ResourceGroupName` | platform | Empty for `subscription` deployments; otherwise the user's resource group (already created, user already `Owner`). |
| `PreferredLocation` | platform | The regions from `lab-defaults.json`, in priority order. Iterate through the list and pick the first region that supports every Azure service your lab needs; skip regions that don't, and emit `Write-Warning` when you skip one (see [authoring guidelines](#authoring-guidelines)). |
| `AllowedEntraUserIds` | platform | Entra object IDs that should be granted access to anything your script provisions beyond the default RBAC. Always contains at least one ID that requires access to the lab. |

> `PreferredLocation` may also be declared as `[string]` (comma-separated) if you
> prefer; the platform detects the type and adapts.

### What the platform guarantees before your script runs

You never need to authenticate. Before your first line executes:

- **Az PowerShell** is logged in from the current federated token, with the
  subscription context set to `$SubscriptionId`. The `Az.Accounts` and
  `Az.Resources` modules are imported.
- **Azure CLI** is logged in with the correct subscription already selected, and
  its login is **isolated to your lab**. That isolation matters because your
  sibling processes are building the *same* lab for *other* participants right
  now: without it, one lab's `az account set` would silently change which
  subscription another lab resolves. `az` calls in your script are therefore
  safe as-is.
- **Lab users are cached**, so [`Get-MhhLabUser`](#get-mhhlabuser) resolves
  `$AllowedEntraUserIds` to UPNs without an Entra round-trip.
- The script runs as a service principal with subscription `Owner`.
- For `resourcegroup` / `resourcegroup-with-subscriptionowner` deployments, the
  resource group named `$ResourceGroupName` already exists at `$PreferredLocation[0]`,
  and the user already has `Owner` on it. The resource group is a metadata-only
  container; you can still deploy individual resources into any other region
  from `$PreferredLocation` if the first region doesn't support a service your
  lab needs (emit `Write-Warning` when you fall back).
- For `subscription` deployments, the user already has `Owner` on the
  subscription, but **no resource group is created**: `$ResourceGroupName` is
  empty. Your script owns RG creation (see [below](#deploying-when-deploymenttype--subscription)).

You do **not** need to call `Connect-AzAccount`, `Set-AzContext` or `az login`,
and for `resourcegroup` / `resourcegroup-with-subscriptionowner` deployments you
do not need to create the resource group or assign the user's `Owner` role.

**OpenTofu is not initialised for you.** This will be done, when your script calls
[`Invoke-MhhTofuCommand`](#invoke-mhhtofucommand); see
[Deploying with OpenTofu](#deploying-with-opentofu).

The helper cmdlets below are auto-imported (no `Import-Module` needed) and all
of them ship full help: `Get-Help Invoke-MhhTofuCommand -Full`.

### Keeping credentials alive in long-running scripts

**The rule:** any *single* command should finish within ~90 minutes. Total
script runtime is unlimited, as long as you refresh between commands.

Az PowerShell, the Azure CLI and OpenTofu each keep using the credential they
logged in with and never renew it themselves, so a script that runs for hours
eventually fails with `AADSTS700024`. Refreshing is one call; you just have to
make it at the right moments:

| Situation | What to do |
| --- | --- |
| Script start | Nothing, already handled |
| `Invoke-MhhDeploymentWithRegionFallback` | Nothing, it refreshes between attempts |
| `Invoke-MhhTofuCommand` | Nothing, it refreshes before each run |
| **Between long phases** | Call [`Update-MhhToken`](#update-mhhtoken) |
| **Before shelling out to raw `az`** | Call [`Update-MhhToken`](#update-mhhtoken) |
| **Polling / waiting loops** | Call [`Update-MhhToken`](#update-mhhtoken) |

> **Never shell out to `tofu` directly.** Always go through
> [`Invoke-MhhTofuCommand`](#invoke-mhhtofucommand): a bare `tofu` misses the
> isolated working directory, the authentication and the credential refresh.

```powershell
Update-MhhToken
```

One call refreshes Az PowerShell, the Azure CLI and OpenTofu authentication
together. It takes **no scope arguments**: the subscription and resource group
come from the platform, so you cannot accidentally point a refresh at another
participant's lab. It is cheap and a no-op when there is nothing new, so just
call it unconditionally at the top of every iteration:

```powershell
foreach ($phase in $phases) {
    Update-MhhToken | Out-Null
    & $phase
}
```

The wrappers refresh best-effort and only warn when that fails, while
`Update-MhhToken` throws. Call it yourself whenever a dead credential must stop
the script.

**What this cannot fix:** a command that is already running. It keeps the
credential it started with, so split long work into phases.

**If a single deployment genuinely needs longer, submit it in the background and
poll.** ARM carries on server-side, and the poll loop refreshes on every pass:

```powershell
$deploymentName = "lab-$(Get-Date -Format yyyyMMddHHmmss)"
New-AzResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName `
    -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') -AsJob -ErrorAction Stop | Out-Null

$deadline = [DateTime]::UtcNow.AddHours(3)
do {
    Start-Sleep -Seconds 30
    Update-MhhToken | Out-Null
    if ([DateTime]::UtcNow -ge $deadline) { throw "Timed out waiting for '$deploymentName'." }
    $state = (Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
        -Name $deploymentName -ErrorAction SilentlyContinue).ProvisioningState
} while ($state -notin 'Succeeded', 'Failed', 'Canceled')

if ($state -ne 'Succeeded') { throw "Deployment '$deploymentName' ended as '$state'." }
```

`-ErrorAction SilentlyContinue` covers the moment before ARM has registered the
deployment, and the deadline stops the loop from waiting forever. Always check
`$state` afterwards: the loop also exits on `Failed` and `Canceled`. Note that
this plain Az pattern gives you no region fallback and no cleanup.

### Deploying when `deploymentType = subscription`

Because the platform does not pre-create a resource group in this mode, you
have two options inside your script:

**Option A: create one or more resource groups yourself.**
Use `Get-MhhStableHash` to derive a deterministic name from
`$AllowedEntraUserIds` so re-runs target the same RG:

```powershell
if ($PreferredLocation.Count -eq 0) { throw 'At least one preferred region is required.' }
$location = $PreferredLocation[0]
$rgName   = "lab-{0}" -f (Get-MhhStableHash -Value $AllowedEntraUserIds -Length 12)

if (-not (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop | Out-Null
}

# Surface the RG name so the user can find it
@{ HackboxCredential = @{ name = "Lab Resource Group"; value = $rgName; note = "" } }
```

> The `Resource Group Name` credential is emitted by the platform for
> `resourcegroup` / `resourcegroup-with-subscriptionowner` deployments. In
> `subscription` mode it is *not* emitted, so surface the group you created
> yourself, under a non-reserved name such as `Lab Resource Group`.

**Option B: do a subscription-scoped deployment.**
Use `New-AzDeployment` (or `New-AzSubscriptionDeployment`) with a template
whose `targetScope` is `subscription`:

```powershell
if ($PreferredLocation.Count -eq 0) { throw 'At least one preferred region is required.' }
$location = $PreferredLocation[0]

New-AzDeployment `
    -Name       ("lab-" + (Get-MhhStableHash -Value $AllowedEntraUserIds -Length 12)) `
    -Location   $location `
    -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject @{ allowedEntraUserIds = $AllowedEntraUserIds } -ErrorAction Stop `
    | Out-Null
```

Either option is fine; pick the one that matches what your lab actually needs
at the subscription scope (e.g. policy assignments, multiple RGs, management
group operations).

Both examples simply take the first preferred region, so check that the services
your lab needs are available there. For `New-AzDeployment`, `-Location` only
stores the deployment record; your template still decides where resources go.

### Deploying with OpenTofu

> **Not recommended, prefer Bicep/ARM.** Three reasons:
>
> - **State does not survive the run.** The working directory lives inside the
>   deployment container, which is thrown away when the job ends. If the whole
>   deployment has to be rescheduled (a failed run, a retry, a second attempt)
>   the new container starts with *no* state, so OpenTofu can
>   neither update nor clean up what the previous run created. Every run is
>   effectively a first run against a scope that may not be empty.
>   **And you have to fix this on your own (e.g. clean up resources first, ...).**
> - **No region fallback and no failure classification.** Bicep/ARM labs get
>   [`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback)
>   and [`Test-MhhDeploymentFailureRetryable`](#test-mhhdeploymentfailureretryable),
>   which turn a capacity or quota error into an automatic retry in the next
>   `$PreferredLocation` region. There is no equivalent for OpenTofu: a
>   `SkuNotAvailable` in your first region simply fails the lab.
> - **A running process cannot be refreshed by the wrapper.** With workload
>   identity, an apply that outlives its credential can fail with `AADSTS700024`
>   and leave partial resources. Keep individual commands short enough for the
>   remaining credential lifetime; ~90 minutes is not a guaranteed allowance.
>
> Use OpenTofu only when your lab genuinely needs something Bicep/ARM cannot
> reach, and design it to be **idempotent from scratch every time**.

Nothing OpenTofu-related is set up in advance: put your `.tf` files in a folder
next to `deploy-lab.ps1` and drive them with
[`Invoke-MhhTofuCommand`](#invoke-mhhtofucommand), which creates and
authenticates the isolated workspace on its first call. Every OpenTofu command
must go through this cmdlet: never invoke `tofu` yourself.

```powershell
$tofuDir = Join-Path $PSScriptRoot 'tofu'
if ($PreferredLocation.Count -eq 0) { throw 'At least one preferred region is required.' }
$prefix = 'lab' + (Get-MhhStableHash -Value $AllowedEntraUserIds -Length 12)

Invoke-MhhTofuCommand -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName `
  -ModulePath $tofuDir -ArgumentList @('init', '-input=false') | Out-Null

Invoke-MhhTofuCommand -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName `
  -Variable @{ location = $PreferredLocation[0]; prefix = $prefix } `
  -TimeoutSeconds 3600 -ArgumentList @('apply', '-auto-approve') | Out-Null
```

The example simply takes the first preferred region: OpenTofu labs get no
automatic region fallback, so check availability yourself.

Points that will save you time:

- **`-ModulePath` is required on the first call.** The content folder is mounted
  read-only, so your `.tf` files are copied into a private working directory
  that is unique to this lab; that is what keeps every participant's copy of
  the *same* module on its own state file and provider tree. Omit `-ModulePath`
  on follow-up calls to reuse what's already there.
- **`-Clean` starts over**: it wipes the workspace, including state, but deletes
  nothing in Azure. Use it on `init` when you deliberately want a fresh start.
- **Never write a `backend` block.** A shared remote backend would make every
  participant's lab write to the same state. State stays local to the
  per-lab working directory, which is already isolated.
- **Keep `init` offline.** The `azurerm` provider ships in the image, so there is
  nothing to download; don't add `-upgrade` and don't reference remote modules.
- **Pass secrets via `-Variable`, never `-var`.** `-Variable` writes them to a
  private file; command lines are readable by anything else in the pod.
- **Auth is automatic.** Don't override provider authentication or put credentials in
  the provider block.

For Bicep/ARM instead, use
[`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback):
it retries in your other `$PreferredLocation` regions on capacity errors.

### Returning credentials to the user (HackboxCredential)

Anything your script writes to the output stream as a `HackboxCredential`
hashtable is captured and surfaced to the user on their personal lab dashboard.
The examples below assume the resources already exist and `$vmPassword` is the
stable password successfully applied to the VM.

```powershell
# Single credential
@{ HackboxCredential = @{
    name  = "AdminPassword"
    value = $vmPassword
    note  = "Initial password for the VM admin account"
} }

# Multiple credentials: emit each as its own hashtable
@{ HackboxCredential = @{ name = "Storage Account"; value = $storageAccount.Name; note = "" } }
@{ HackboxCredential = @{ name = "Storage Key";     value = $key;                 note = "Primary key" } }
```

Rules:

- **Emit hashtables**: a `PSCustomObject` is ignored.
- `name` and `value` are required and must be non-empty.
- `note` is optional context shown next to the credential.
- Emit each credential as a separate hashtable; do not wrap them in an array.
- **Re-emitting a `name` overwrites the stored value**, so emit a credential only
  once the resource actually has that value; otherwise a run that fails midway
  can leave a password on the dashboard that was never applied.
- Derive passwords with [`New-MhhStablePassword`](#new-mhhstablepassword) so they
  survive a re-run; see [Passwords and re-runs](#passwords-and-re-runs). The
  platform handles assigning the credential to the right lab and user.
- The platform reserves certain credential names (e.g. `Subscription ID`,
  `Resource Group Name`, `Entra ID *`, `Portal URL *`) and emits them itself.
  Attempts to emit a reserved name are silently dropped.

#### Passwords and re-runs

A credential is stored the moment you emit it, and the participant may already
be using it. If a re-run (an idempotent redeploy, or a region-fallback retry that
wipes and recreates the resource group) generates a *new* random password, the
one on the dashboard silently stops working.

So **derive credentials, do not randomise them**:

```powershell
$vmPassword = New-MhhStablePassword -Purpose 'vm-admin'
```

[`New-MhhStablePassword`](#new-mhhstablepassword) returns the same value on every
run for a given lab and purpose, so the dashboard stays correct no matter how
often the script runs.

### Cleaning up

You normally **do not clean up**: the platform deletes the participant's scope when
the event ends. Two cases need action from your script:

- **You hand-roll a region fallback with the Azure CLI or OpenTofu.** Neither path
  can use [`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback),
  so when the first region does not offer capacity, you have to wipe the resource
  group and recreate it in the next `$PreferredLocation` region yourself. Two
  things to get right:

  1. Use [`Remove-MhhResourceGroup`](#remove-mhhresourcegroup) rather than
     `Remove-AzResourceGroup`, so backup vaults are drained first and
     soft-deletable names (Key Vault, Cognitive Services / AI Foundry, App
     Configuration, APIM, ML workspaces) are purged afterwards. Otherwise the
     retry in the next region collides with its own leftovers.
  2. **Deleting the resource group also deletes the participant's `Owner`
     assignment on it.** Re-grant `Owner` to every ID in `$AllowedEntraUserIds`
     after you recreate the group, or the user loses access to their own lab.

  ```powershell
  Update-MhhToken | Out-Null
  $teardown = Remove-MhhResourceGroup -ResourceGroupName $ResourceGroupName
  if (-not $teardown.ManifestCaptured -or $teardown.Errors.Count -gt 0 -or $teardown.SoftDeletedResidual.Count -gt 0) {
    throw "Cleanup incomplete: $($teardown.Errors -join '; ')"
  }
  New-AzResourceGroup -Name $ResourceGroupName -Location $nextLocation -ErrorAction Stop | Out-Null

  foreach ($userId in $AllowedEntraUserIds) {
    New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName 'Owner' `
      -ResourceGroupName $ResourceGroupName -ErrorAction Stop | Out-Null
  }
  ```

- **You used OpenTofu and deleted the resource group.** Drop the isolated working
  directory too with
  [`Remove-MhhTofuWorkspace`](#remove-mhhtofuworkspace), so the next run does not
  reuse the previous run's state.

For RG-scoped Bicep/ARM labs,
[`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback)
handles reuse, any required teardown/recreation and Owner assignment. Pass
`$AllowedEntraUserIds` to `-RgOwnerEntraObjectIds` and inspect teardown warnings:
the helper reports incomplete cleanup but can still proceed to deployment.

### Local testing

You can run `deploy-lab.ps1` and `shared-deploy-lab.ps1` on your own machine in
a PowerShell environment similar to the one used by the platform. Use the
[`adminpwsh`](https://github.com/qxsch/adminpwsh) container image:

```powershell
docker run -it -v '.\:/app' --rm "ghcr.io/qxsch/adminpwsh:latest"
```

This mounts the current folder (the `labautomation` folder containing
`deploy-lab.ps1` and `shared-deploy-lab.ps1`) at `/app` inside the container.
Once inside the container's shell, authenticate Az PowerShell and the Azure
CLI. Unlike a platform-triggered run, you need to log in yourself:

```powershell
Connect-AzAccount -UseDeviceAuthentication
az login --use-device-code
# optional, if you use Set-MhhManagedIdentityRoleMember cmdlet:    Connect-MgGraph -UseDeviceCode -Scopes 'Application.Read.All','RoleManagement.ReadWrite.Directory'

$rg = "lab-local-test"
if (Get-AzResourceGroup -Name "$rg" -ErrorAction SilentlyContinue) {
    throw "Resource group '$rg' already exists. Please delete the rg first."
}
New-AzResourceGroup -Name "$rg" -Location "swedencentral"
```

Then run the script exactly as the platform would, passing at least the
required parameters from the [contract](#required-parameter-contract):

```powershell
# like this for resourcegroup deployments
./deploy-lab.ps1 -DeploymentType resourcegroup -SubscriptionId (Get-AzContext).Subscription.Id -ResourceGroupName "$rg" -PreferredLocation 'swedencentral' -AllowedEntraUserIds (Get-AzADUser -SignedIn).Id
```

> The helper cmdlets (`New-MhhStablePassword`, `Get-MhhStableHash`,
> `Update-MhhToken`, `Invoke-MhhTofuCommand`, …) are simplified local-dev stand-ins.
> They are not identical to the platform versions, but they are sufficient for
> testing your script logic and parameter contract.

## Optional hook: `shared-deploy-lab.ps1`

`deploy-lab.ps1` deliberately only ever sees one lab. That is what makes it safe
to run 50 times in parallel, but it also means there is no place in it for work
that must happen **once per subscription** rather than once per participant.
[`shared-deploy-lab.ps1`](shared-deploy-lab.ps1) fills exactly that gap: the
platform runs it once for every subscription that holds labs, **before** the
first `deploy-lab.ps1` starts, so whatever it provisions is already in place
when the individual labs are built on top of it.

Use it for:

- **Shared resources** several labs in the same subscription are meant to use:
  a hub VNet the participant spokes peer into, a central Log Analytics
  workspace, a shared AI Foundry / OpenAI resource whose quota you do not want
  to multiply by the number of participants.
- **One-off subscription preparation** that every parallel `deploy-lab.ps1`
  would otherwise race on or duplicate: registering resource providers,
  accepting Azure Marketplace image terms — anything that is a property of the
  *subscription* rather than of a lab.

The script is optional and independent: you can ship it without a
`deploy-lab.ps1`, and vice versa. As with `deploy-lab.ps1`, its param block is
validated before it runs — a mismatch means the hook is skipped with a warning
in the job log and the labs are built without it, so keep the parameter names
and types exactly as documented below.

### Where it fits in the pipeline

| | `shared-deploy-lab.ps1` | `deploy-lab.ps1` |
| --- | --- | --- |
| Invocations | once per subscription | once per lab |
| Timing | after every lab's scope + RBAC exist, **before any lab is built** | after the shared stage finished successfully |
| Concurrency | parallel, one job per subscription | parallel, one job per lab |
| Azure scope handed in | one subscription, **no** resource group (create your own) | one subscription **+** that lab's resource group |
| lab handed in | **every** lab in that subscription | exactly one |
| `HackboxCredential` output | stored for **every** lab in that subscription | stored for that one lab |
| On failure | **no** `deploy-lab.ps1` runs at all, in any subscription; deployment marked failed | the lab is marked failed |
| Helper cmdlets, Az / Azure CLI login, `Get-MhhLabUser` | available | available |

> **One failing subscription blocks the whole event.** The gate is global, not
> per subscription: if the shared hook fails for *one* subscription, the
> platform skips `deploy-lab.ps1` for *every* participant and fails the
> deployment. Idempotency is therefore critical!

### Shared hook parameter contract

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$PreferredLocation,

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)
```

| Parameter | Provided by | Notes |
| --- | --- | --- |
| `SubscriptionId` | platform | The subscription this invocation is responsible for. Az PowerShell and the Azure CLI already point at it. |
| `PreferredLocation` | platform | The regions from `lab-defaults.json`, in priority order. May be declared as `[string]` (comma-separated) or `[string[]]`; the platform detects the type and adapts, exactly as for `deploy-lab.ps1`. |
| `AllowedEntraUserIds` | platform | **All** participants holding a lab in this subscription — up to `labsPerSubscription` of them, or exactly one when `deploymentType` is `subscription`. |

### Rules for the shared hook

- **`$AllowedEntraUserIds` is a list, not a single user.** Grant RBAC on
  everything you create to *all* of them; the platform assigns no roles on the
  resources this hook provisions.
- **There is no `$ResourceGroupName`.** Create your own resource group and never
  deploy into a participant's. A fixed name such as `rg-shared` is fine — the
  subscription only ever holds this one event's labs — or derive one with
  [`Get-MhhStableHash`](#get-mhhstablehash).
- **`Invoke-MhhDeploymentWithRegionFallback` can delete its target RG** during
  recycle or region changes. Use a dedicated shared RG that the template can
  fully rebuild, never a participant's RG. Initial reuse is not a guarantee of
  preservation if a later phase fails.
- **Emitted credentials fan out to every participant in the subscription.** The
  right behaviour for a shared endpoint, hostname or resource group name; never
  emit a per-participant secret from here.
- **Hand results down through the dashboard, not through variables.**
  `deploy-lab.ps1` runs in a separate process and receives nothing from this
  hook. If a lab needs to find the shared resources, either look them up in the
  lab (`Get-AzResource`, a well-known name or tag) or surface them as a
  `HackboxCredential`.
- **`deploy-lab.ps1` may assume the shared resources exist** — that is the whole
  point of the ordering — but only if this hook is genuinely finished. Don't
  submit long ARM deployments with `-AsJob` and return before they complete.
- **Be idempotent.** The hook re-runs whenever the deployment is re-run,
  including after a partial failure. Guard with
  `-ErrorAction SilentlyContinue` + `if (-not …)`, or redeploy the same template.
- **Registration is asynchronous.** `Register-AzResourceProvider` returns
  immediately; a provider may still be `Registering` when the labs start.
  Register here, and re-check in `deploy-lab.ps1` if a provider is mandatory.
- **Everything else matches `deploy-lab.ps1`:** its own process, Az PowerShell
  and the Azure CLI logged in against `$SubscriptionId` with an isolated CLI
  login, the lab-user cache pre-seeded (so
  [`Get-MhhLabUser`](#get-mhhlabuser) is free) and all helper cmdlets
  auto-imported. [`Update-MhhToken`](#update-mhhtoken) is scoped to the
  subscription and takes no scope arguments here either. Do not call
  `Connect-AzAccount`, `Set-AzContext` or `az login`.

### Example: a shared hub network

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation,

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

$sharedResourceGroup = 'rg-shared'

$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $PreferredLocation `
    -ResourceGroupName       $sharedResourceGroup `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            (Join-Path $PSScriptRoot 'shared.bicep') `
    -TemplateParameterObject @{ userIds = $AllowedEntraUserIds } `
    -DeploymentNamePrefix    'shared'

# Shown on the dashboard of every participant in this subscription.
@{ HackboxCredential = @{
    name  = 'Shared Resource Group'
    value = $sharedResourceGroup
    note  = 'Shared by all labs in your subscription'
} }
@{ HackboxCredential = @{
    name  = 'Hub VNet'
    value = [string]$result.Outputs['hubVnetName']
    note  = ''
} }
```

`deploy-lab.ps1` can then peer each participant's spoke into `rg-shared`,
because the hub is guaranteed to exist by the time it runs.

### Testing the shared hook locally

Same [`adminpwsh`](https://github.com/qxsch/adminpwsh) container and login steps
as in [Local testing](#local-testing); only the invocation differs:

```powershell
./shared-deploy-lab.ps1 `
    -SubscriptionId       (Get-AzContext).Subscription.Id `
    -PreferredLocation    "swedencentral" `
    -AllowedEntraUserIds  (Get-AzADUser -SignedIn).Id
```

Pass `-PreferredLocation` as a comma-separated string or as an array, matching
however you declared it. Run the scripts in the real order —
`shared-deploy-lab.ps1` first, then `deploy-lab.ps1` — if you want to reproduce
what the platform does. Pass more than one object ID to `-AllowedEntraUserIds`
to check that your RBAC really covers every participant.

## Available helper cmdlets

The platform ships a PowerShell module that is auto-imported into your script
(and into any `Start-Job` child runspaces you spawn). No `Import-Module` call
is required. Every cmdlet has full comment-based help:
`Get-Help Invoke-MhhTofuCommand -Full`.

### `New-MhhStablePassword`

Derive a password that is **the same on every re-run** for a given lab, purpose
and length. An idempotent redeploy, or
a region-fallback retry that wipes and recreates the
resource group, keeps the credential already shown on the participant's
dashboard valid.

```powershell
$vmPassword  = New-MhhStablePassword -Purpose 'vm-admin'
$sqlPassword = New-MhhStablePassword -Purpose 'sql-admin' -Length 24
```

Emit these values **only after** the corresponding resources have successfully
accepted them:

```powershell
@{ HackboxCredential = @{ name = 'VM Admin Password'; value = $vmPassword; note = 'vm-01' } }
@{ HackboxCredential = @{ name = 'SQL Admin Password'; value = $sqlPassword; note = 'sql-01' } }
```

| Parameter | Description |
| --- | --- |
| `Purpose` (`string`, positional 0) | Distinguishes multiple passwords within one lab (`vm-admin`, `sql-admin`, …). Different purposes give unrelated passwords for the same lab. Default `default`. |
| `Length` (`int`, 16 - 128) | Default 16. |
| `SubscriptionId` (`string`) | Scope override. Defaults to the lab's subscription. Leave it alone. |
| `ResourceGroupName` (`string`) | Scope override. Defaults to the lab's resource group, empty for subscription-scoped labs. Leave it alone. |
| `Secret` (`string`) | Local development and tests only; on the platform this is provided for you. |
| `AsSecureString` (`switch`) | Return a `SecureString`, useful for a Bicep `@secure()` parameter. |

**Return value:** one plaintext `string`, or one `SecureString` with
`-AsSecureString`.

- **Scoped to the lab, so no two participants share a password.** The platform
  supplies the lab scope, so in practice you pass only `-Purpose` (and `-Length`
  when the default is too short). Overriding the scope changes the derived
  password and breaks the "same value on every re-run" guarantee.
- **Output is `[A-Za-z0-9]` only**, so it survives connection strings, YAML, JSON
  and shell quoting with no escaping, and always contains at least one lowercase,
  one uppercase and one digit, enough for the Azure VM and SQL "3 of 4 character
  classes" rule without a special character.

### `Get-MhhStableHash`

Deterministic, order-insensitive hash of one or more strings, useful for
generating stable resource names.

```powershell
# 24-char hex hash (default length)
$hash = Get-MhhStableHash -Value $AllowedEntraUserIds

# Use it to name a resource group / storage account / etc.
$rgName = "lab-$hash"
```

| Parameter | Description |
| --- | --- |
| `Value` (`string[]`, required, positional 0) | One or more non-empty strings to hash. Accepts pipeline input. |
| `Length` (`int`, optional) | Number of hex chars to return. Range 12 - 64. Default 24. |

**Return value:** a lowercase hex `string` of the requested length. Order and
casing do not matter, but duplicates and surrounding whitespace do, so pass a
clean list.

It is an unkeyed hash, so use it for resource **names**. For passwords use
[`New-MhhStablePassword`](#new-mhhstablepassword), which is keyed.

### `Get-MhhLabUser`

Resolve the Entra object IDs you receive in `$AllowedEntraUserIds` to lab-user
records (`UserPrincipalName` + a short, lowercase name). Content scripts only
get bare object IDs; use this cmdlet whenever you need the user's UPN or a
human-friendly name (e.g. to tag resources, build a greeting, or derive a
stable per-user resource name).

```powershell
# Resolve the single user this invocation is for
$me = Get-MhhLabUser -UserId $AllowedEntraUserIds[0]
Write-Host "Deploying for $($me.UserPrincipalName) ($($me.ShortName))"

# Or resolve many at once via the pipeline
$AllowedEntraUserIds | Get-MhhLabUser | ForEach-Object { $_.ShortName }
```

| Parameter | Description |
| --- | --- |
| `UserId` (`string[]`, required) | One or more Entra object IDs (GUIDs). Also accepts the aliases `-ObjectId` / `-Id`, and accepts pipeline input. |

**Return value**: one `PSCustomObject` per input ID:

| Field | Description |
| --- | --- |
| `Id` | The Entra object ID you passed in. |
| `UserPrincipalName` | The user's UPN (e.g. `user01@contoso.onmicrosoft.com`). |
| `ShortName` | The lowercase local part of the UPN (the bit before `@`), handy for resource names and greetings. |

The platform pre-seeds a cache before your script runs, so lookups normally cost
nothing; an ID that is not cached is fetched from Entra ID, and a failed fetch
throws. `ShortName` is not sanitised, so check the naming rules of whatever you
name with it.

### `Update-MhhToken`

Refresh the Azure credential for **every** client at once: Az PowerShell, the
Azure CLI and OpenTofu. This is the cmdlet a long-running `deploy-lab.ps1` calls
between phases; see
[Keeping credentials alive](#keeping-credentials-alive-in-long-running-scripts)
for when it's needed.

```powershell
Update-MhhToken
```

| Parameter | Description |
| --- | --- |
| `Target` (`string[]`) | Restrict to `AzPowerShell`, `AzureCli` and/or `OpenTofu`. Defaults to every client installed in the image. Naming a target that isn't installed is an error. |
| `MinimumRemainingMinutes` (`int`, 0 - 1440) | Warn when the refreshed credential has less life left than the longest single command still to run. `0` (default) disables the check, which only ever warns. |

Clients that are already current are skipped, so calling this in a loop is cheap.

Returns `@{ Mode; Rotated; TokenLifetimeSeconds; RemainingSeconds; Refreshed; Skipped }`
and **throws** if a refresh it attempted fails, so you can't silently continue
with dead credentials.

### `Invoke-MhhSynchronized`

Run a script block under a container-wide exclusive lock. Use it around short
critical sections that mutate shared state and could otherwise race when
participant deployments run in parallel, such as adding subnets to a shared
VNet.

```powershell
$lockName = 'vnet-' + (Get-MhhStableHash -Value $SubscriptionId, $sharedRg, $vnetName)
Invoke-MhhSynchronized -Name $lockName {
  $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $sharedRg -ErrorAction Stop
  if ($vnet.Subnets.Name -notcontains $subnetName) {
    Add-AzVirtualNetworkSubnetConfig `
      -VirtualNetwork $vnet `
      -Name $subnetName `
      -AddressPrefix $addressPrefix -ErrorAction Stop |
      Set-AzVirtualNetwork -ErrorAction Stop | Out-Null
  }
}
```

| Parameter | Description |
| --- | --- |
| `ScriptBlock` (`scriptblock`, required, positional 0) | Critical section to run while holding the lock. Its output and exceptions pass through unchanged. |
| `Name` (`string`, positional 1) | Case-insensitive lock name, 1-64 characters from `[A-Za-z0-9._-]`. Default `Default`. |
| `TimeoutSeconds` (`int`, 1-86400) | How long to wait *for the lock* before throwing. Default 900. |
| `MaxSleepDelayMilliseconds` (`int`, 250-1000000) | Upper bound for the small random delay after a call that had to queue. Default 1000. |

- **Locks are container-wide and keyed only by `Name`.** Calls using the same
  name serialize even across subscriptions, so give unrelated critical sections
  different names, and every writer to one shared resource the same name.
- **Keep the script block short.** Every other job waiting for that name stays
  blocked until it finishes. The lock is released even if the block throws.
- **Local variables work without `$using:`**, but assignments inside the block do
  not update the caller's variables: return a value instead. Nested calls using
  the same name are supported.

**Return value:** whatever the script block emits. Errors propagate after the
lock is released, so use `-ErrorAction Stop` inside the block when a failure
must stop your script.

### `Set-MhhManagedIdentityRoleMember`

Grant an Entra ID directory role to the system-assigned managed identities of
supported Azure resources. Your lab has no Graph permissions of its own, so the
platform performs the assignment for you and waits for the result. Existing
memberships come back as `AlreadyAssigned`, so re-running is safe.

**Only works inside a platform-run lab**, so this is the one helper you cannot
try out locally.

Supported resource types:

- `Microsoft.Sql/managedInstances`
- `Microsoft.Compute/virtualMachines`
- `Microsoft.Web/sites`
- `Microsoft.App/containerApps`

Only the **Directory Readers** role is supported, and each ID must point at a
top-level resource of one of those types.

**It is all-or-nothing:** if one ID is unsupported, or its managed identity is
not visible in Entra ID yet, the whole request fails and nothing is assigned.
Create the identities first and allow for a short propagation delay.

```powershell
$roleResults = @(Get-AzSqlInstance -ResourceGroupName $ResourceGroupName -ErrorAction Stop |
  Set-MhhManagedIdentityRoleMember -Role 'Directory Readers')
if ($roleResults.Count -eq 0 -or @($roleResults | Where-Object { $_.status -ne 'Assigned' -and $_.status -ne 'AlreadyAssigned' }).Count -gt 0) {
  throw 'Not every managed identity received Directory Readers.'
}
```

| Parameter | Description |
| --- | --- |
| `ResourceId` (`string[]`, required, positional 0) | Azure resource IDs whose system-assigned identities receive the role.<br><br>Supported providers:<br>• `Microsoft.Sql/managedInstances`<br>• `Microsoft.Compute/virtualMachines`<br>• `Microsoft.Web/sites`<br>• `Microsoft.App/containerApps`<br><br>Accepts pipeline input and the aliases `Id` and `ResourceIds`. Duplicate IDs are processed once. |
| `Role` (`string[]`, positional 1) | Directory roles to grant. Only `Directory Readers` is supported. Default `Directory Readers`. |
| `TimeoutSeconds` (`int`, 60-3600) | How long to wait for the platform to finish the assignment. Default 900. |

**Return value:** one result object per resource and role combination:

| Field | Description |
| --- | --- |
| `resourceId` | Azure resource ID supplied to the helper. |
| `principalId` | The managed identity's object ID. |
| `displayName` | Azure resource / managed identity display name. |
| `role` | Resolved directory role name. |
| `status` | `Assigned`, `AlreadyAssigned`, `Skipped` or `Failed`. |

A failed request throws, but a single resource can still come back as `Failed`
while the rest succeed, so check every status as in the example.

### `Invoke-MhhTofuCommand`

Run one OpenTofu command in a workspace that is isolated to this lab. Every
participant's process runs the *same* `.tf` module, so this isolation is what
stops them sharing OpenTofu state. See
[Deploying with OpenTofu](#deploying-with-opentofu) for the usage rules.

```powershell
Invoke-MhhTofuCommand -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName `
    -ModulePath (Join-Path $PSScriptRoot 'tofu') -Clean init -input=false
```

| Parameter | Description |
| --- | --- |
| `ArgumentList` (`string[]`, required, positional 0) | Arguments passed to `tofu`. Trailing arguments are accepted positionally; use the explicit array form for a bare flag that could clash with a parameter name here (e.g. tofu's `-var`). |
| `SubscriptionId` (`string`, required) | The lab's subscription. Selects the provider subscription and the isolated workspace. Pass `$SubscriptionId` straight through. |
| `ResourceGroupName` (`string`) | Pass `$ResourceGroupName`. Omit for subscription-scoped labs, which get their own workspace. |
| `ModulePath` (`string`) | Directory holding the `.tf` files. Copied into the workspace before the command runs. Required on the first call and after `-Clean`; omit afterwards. |
| `Variable` (`hashtable`) | Template variables, kept off the command line and reused by later calls. Pass the full set, not an incremental update. |
| `AuthMode` (`string`) | `Auto` (default), `WorkloadIdentity`, `Msi` or `AzureCli`. |
| `TimeoutSeconds` (`int`, 0–86400) | Kill the process tree after this many seconds. `0` (default) waits indefinitely. |
| `Clean` (`switch`) | Delete the workspace before running, including state. Deletes nothing in Azure. |
| `IgnoreExitCode` (`switch`) | Return the result instead of throwing when `tofu` exits non-zero or times out. |
| `SkipCredentialRefresh` (`switch`) | Skip the credential refresh that otherwise runs before each invocation. |

**Return value:** one hashtable:

| Field | Type | Description |
| --- | --- | --- |
| `Success` | `bool` | `tofu` exited `0` and did not time out. |
| `ExitCode` | `int` | Native `tofu` exit code. |
| `WorkingDirectory` | `string` | The workspace the command ran in. |
| `Output` | `array` | Captured stdout and stderr lines, also written to the job log. |
| `DurationSeconds` | `int` | How long `tofu` ran. |
| `TimedOut` | `bool` | The command hit `TimeoutSeconds` and was killed. |

Non-zero exits and timeouts throw unless `-IgnoreExitCode` is set. A failed
credential refresh only warns, so call `Update-MhhToken` first if that must stop
your script.

Variables, state and output can contain secrets, so don't print them and don't
pass secrets in `ArgumentList`. Run only one OpenTofu command at a time per lab.

### `Remove-MhhTofuWorkspace`

Delete the isolated OpenTofu working directory for one subscription + resource
group. Only this lab's own directory is removed, so the other participants' labs
building concurrently are untouched.

**Purpose:** if your script deletes the resource group itself, drop the OpenTofu working directory too so the next run starts with a clean workspace and does not accidentally reuse the previous run's state.

```powershell
$cleanup = Remove-MhhTofuWorkspace -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName
if ($cleanup.Errors.Count -gt 0) { throw ($cleanup.Errors -join '; ') }
```

| Parameter | Description |
| --- | --- |
| `SubscriptionId` (`string`, required, positional 0) | Lab subscription. Pass `$SubscriptionId` straight through. |
| `ResourceGroupName` (`string`, positional 1) | Pass `$ResourceGroupName`. Omit for subscription-scoped labs. |
| `IncludeAzCliContext` (`switch`) | Also delete this lab's isolated Azure CLI login. |

**Return value:** a hashtable:

| Field | Type | Description |
| --- | --- | --- |
| `WorkspacePath` | `string` | The workspace that was targeted. |
| `Removed` | `bool` | This call actually removed the workspace. `false` for a missing workspace or a deletion error. |
| `AzCliConfigPath` | `string` or `$null` | The Azure CLI login that was targeted, when you asked for it to go too. |
| `AzCliRemoved` | `bool` | This call actually removed that CLI login. |
| `Errors` | `array` | Deletion errors. A missing workspace is not an error. |

Nothing in Azure is deleted and `tofu destroy` is not run, so tear the resource
group down separately. Wait for any running OpenTofu command to finish first.

### `Invoke-MhhDeploymentWithRegionFallback`

Deploy a Bicep / ARM template into a resource group with **automatic region
fallback** when Azure returns capacity, quota, or region-unsupported errors.
This is the recommended way to ship an RG-scoped Bicep template from
`deploy-lab.ps1`: it removes the need to hand-roll the
`foreach ($region in $PreferredLocation) { try { … } }` loop documented in the
[authoring guidelines](#authoring-guidelines).

An existing RG that is not `Deleting` and sits in one of your preferred regions
is **reused**, and that region is tried first. A re-run therefore updates a
working lab instead of rebuilding it. To start from an empty RG, call
[`Remove-MhhResourceGroup`](#remove-mhhresourcegroup) first.

| Phase | What happens |
| --- | --- |
| `Reuse` | Deploy into the existing RG, in its current region, without touching its resources. |
| `Recycle` | Reuse failed retryably: wipe the RG and try again in the **same region** before moving on. |
| `Fresh` | Create the RG in the next region, wiping an existing one first if its region differs. |

Every phase grants `Owner` to `RgOwnerEntraObjectIds` (so **pass
`$AllowedEntraUserIds`**, or the user loses access after a recreate), runs your
optional hook, and submits an incremental deployment.

Your template must follow the chosen region — normally a location parameter
defaulting to `resourceGroup().location`. A location hardcoded in your parameters
would keep deploying to the old region even after a fallback.

On failure the error is classified by
[`Test-MhhDeploymentFailureRetryable`](#test-mhhdeploymentfailureretryable):

| Classification | Behaviour |
| --- | --- |
| Fatal (template bug, RBAC, policy, name collision…) | Re-throws immediately. No further regions are tried. |
| Retry-next-region (`SkuNotAvailable`, `QuotaExceeded`, `LocationNotAvailableForResourceType`, `ResourceProviderUnavailable`, …) | Moves on to the next phase or region. |
| Same-region transient (`TooManyRequests`, `OperationTimedOut`, `ServiceUnavailable`, conflicts, a name still held by a soft-deleted resource) | Resubmits into the same RG (`-SameRegionRetryBudget`, default 1), then moves on. |

If every region is exhausted, the helper throws `RegionFallbackExhausted` with a
per-attempt summary. Credentials are refreshed automatically between attempts.

**Parameters:**

| Parameter | What to pass |
| --- | --- |
| `PreferredLocations` (`string[]`, required) | Pass `$PreferredLocation` straight through. If your script declared it as a comma-separated string, split it first. |
| `ResourceGroupName` (`string`, required) | For `resourcegroup` / `resourcegroup-with-subscriptionowner`: pass `$ResourceGroupName`. For `subscription`: derive a stable name with `Get-MhhStableHash`. |
| `RgOwnerEntraObjectIds` (`string[]`) | **Pass `$AllowedEntraUserIds`**, so the user keeps `Owner` on the RG after a recreate. |
| `TemplateFile` (`string`, required) | Path to your `.bicep` / `.json` template (e.g. `Join-Path $PSScriptRoot 'main.bicep'`). |
| `TemplateParameterObject` (`hashtable`) | Your template parameters. Mutually exclusive with `TemplateParameterFile`. |
| `TemplateParameterFile` (`string`) | Parameter file path. Mutually exclusive with `TemplateParameterObject`. |
| `DeploymentNamePrefix` (`string`) | Prefix for the ARM deployment name (the final name adds region and timestamp). Default `mhh`. |
| `MaxAttempts` (`int`, 0-50) | Caps how many **regions** are tried. Default `0` = one per region; same-region retries don't count. |
| `CleanupTimeoutSeconds` (`int`, 60-3600) | How long to wait for a resource-group delete before retrying it. Default `600`. |
| `CleanupRetryBudget` (`int`, 0-5) | Extra delete attempts when an RG is slow to disappear. Default `2`. |
| `SameRegionRetryBudget` (`int`, 0-5) | Extra submissions into the same RG on transient errors before rotating. Default `1`. |
| `Tag` (`hashtable`) | Tags for the RG, applied on every attempt and merged when the RG is reused. The helper adds its own `microhack-attempt-*` keys on top. |
| `PreDeployHook` (`scriptblock`) | Runs once the RG is ready, before the deployment, with the chosen location as its argument — e.g. `Register-AzResourceProvider`. Best-effort: if it throws, the deployment still runs. |
| `AssumeRetryableOnUnknown` (`switch`) | Treat unknown ARM error codes as retryable instead of fatal. Off by default; leave it off so real template bugs fail fast. |

**Return value on success** (a hashtable):

| Field | Description |
| --- | --- |
| `Success` | `$true` |
| `LocationUsed` | The region the deployment actually succeeded in. |
| `DeploymentName` | Full ARM deployment name. |
| `Outputs` | Hashtable of template outputs (`name → value`), flattened for direct use. |
| `DeploymentResult` | Raw `PSResourceGroupDeployment` object. |
| `Attempts` | One record per try: region, phase, outcome, classification and duration. |
| `ReusedExistingResourceGroup` | `$true` when the successful deployment went into an RG that already existed. |

Feed `Outputs` into `HackboxCredential` hashtables: that is the typical bridge
between your Bicep `output` blocks and the user's dashboard. Publish only what
the participant should see.

**Example: RG-scoped Bicep deployment with region fallback:**

These examples assume you have implemented `main.bicep` with a `userObjectId`
parameter and resource locations derived from `resourceGroup().location`.
Adapt the parameter names to your template; the template in this folder is a
placeholder.

```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",
    [string[]]$PreferredLocation = @(),
    [string[]]$AllowedEntraUserIds = @()
)

if ($DeploymentType -eq 'subscription') {
    $ResourceGroupName = 'myrg'
}

$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $PreferredLocation `
    -ResourceGroupName       $ResourceGroupName `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject @{
        userObjectId = $AllowedEntraUserIds[0]
    } `
    -DeploymentNamePrefix    'lab'

@{ HackboxCredential = @{ name = "Region"; value = $result.LocationUsed; note = "" } }
@{ HackboxCredential = @{ name = "Lab Resource Group"; value = $ResourceGroupName; note = "" } }
```

**Example: setting static tags on the resource group via `-Tag`:**

For plain, known-upfront tag values, pass `-Tag` directly: the helper applies
them on every attempt, whether it creates the RG or reuses an existing one. No
follow-up tagging call is required.

```powershell
$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations      $PreferredLocation `
    -ResourceGroupName       $ResourceGroupName `
    -RgOwnerEntraObjectIds   $AllowedEntraUserIds `
    -TemplateFile            (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject @{
        userObjectId = $AllowedEntraUserIds[0]
    } `
    -Tag                     @{ 'some-tag' = 'myvalue' }
```

**When *not* to use it:**

- You are not doing an ARM/Bicep deployment (e.g. you only call individual
  `New-Az*` cmdlets). Use the manual
  [region-iteration pattern](#authoring-guidelines) instead.
- You need a `subscription`-scoped deployment (`New-AzDeployment`). This helper
  is RG-scoped only.
- You must preserve resources across **all** retries. Initial reuse is
  non-destructive, but recycle and region changes can delete the entire RG.
  The template must be able to rebuild a complete lab.

### `Test-MhhDeploymentFailureRetryable`

Lower-level classifier used internally by
`Invoke-MhhDeploymentWithRegionFallback`. Call it directly only if you've
hand-rolled your own deployment loop and need to make the same
fatal / retry-next-region / same-region-transient decision.

**Parameters:**

| Parameter | Description |
| --- | --- |
| `ErrorRecord` (`ErrorRecord`, required) | The terminating error caught from `New-AzResourceGroupDeployment`. |
| `ResourceGroupName` (`string`) | Lets the helper drill into the deployment's operations, and re-validate the template when the outer error is only an opaque wrapper (`DeploymentFailed` / `InvalidTemplateDeployment`). |
| `DeploymentName` (`string`) | Name of the failed deployment; needed for that drill-in. |
| `TemplateFile` (`string`) | Enables the re-validation. Without it, a wrapper-only failure stays blind. |
| `TemplateParameterObject` (`hashtable`) | Parameters for the re-validation. Pass what the deployment used. Mutually exclusive with `TemplateParameterFile`. |
| `TemplateParameterFile` (`string`) | Parameter file for the re-validation. Mutually exclusive with `TemplateParameterObject`. |
| `AssumeRetryableOnUnknown` (`switch`) | Treat unknown ARM error codes as retryable instead of fatal. Off by default. |

This diagnostic example assumes `$splat` contains `Name`, `ResourceGroupName`,
`TemplateFile` and `TemplateParameterObject` for the deployment. It reports the
verdict and deliberately rethrows; use the verdict inside a bounded retry loop
only when you own that loop's cleanup and access-restoration logic.

```powershell
$splat.ErrorAction = 'Stop'
try {
    New-AzResourceGroupDeployment @splat
}
catch {
    $verdict = Test-MhhDeploymentFailureRetryable `
        -ErrorRecord       $_ `
    -ResourceGroupName $splat.ResourceGroupName `
    -DeploymentName    $splat.Name `
    -TemplateFile      $splat.TemplateFile `
    -TemplateParameterObject $splat.TemplateParameterObject

  Write-Warning "Deployment failed: $($verdict.Classification), code=$($verdict.MatchedCode), retryable=$($verdict.IsRetryable), sameRegion=$($verdict.SameRegionRetry), backoff=$($verdict.RetryAfterSeconds)s."
  throw
}
```

It reads the error, the failed deployment operations and, when those say nothing
useful, a re-validation of your template. It only inspects — it never deploys,
deletes or retries anything itself.

**Return value** (a hashtable):

| Field | Type | Description |
| --- | --- | --- |
| `IsRetryable` | `bool` | `$true` if you should retry (in this region or the next), `$false` if you must give up. |
| `SameRegionRetry` | `bool` | When retryable: `$true` = resubmit into the **same** region first, `$false` = rotate to the **next** region. |
| `Classification` | `string` | `Fatal`, `CapacityShortage`, `QuotaExceeded`, `RegionUnsupported`, `ResourceProviderUnavailable`, `RegionalFailure`, `TransientThrottle`, `ResourceConflict`, `SoftDeletedNameInUse`, `OpaqueNoEvidence`, `UnknownAssumedFatal` or `UnknownAssumedRetryable`. |
| `MatchedCode` | `string` | The ARM error code that drove the decision (e.g. `SkuNotAvailable`, `QuotaExceeded`, `TooManyRequests`). `$null` when none was recognised. |
| `AllCodes` | `array` | Every error code that was considered, useful for logging. |
| `Reason` | `string` | The error message, truncated to 500 characters. |
| `RetryAfterSeconds` | `int` | Suggested backoff: `60` for conflicts, `120` for soft-deleted names, otherwise `30`. |

A code that is not recognised is fatal by default, so a real template bug fails
fast instead of burning quota in every region.

For most labs, prefer
[`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback)
and you won't need to call this directly.

### `Remove-MhhResourceGroup`

Delete a resource group and **attempt to release the names it held**, so the
same template can be redeployed with the same names. A plain
`Remove-AzResourceGroup` is not enough: backup vaults block the delete, and
soft-deletable resources (Key Vault, Cognitive Services / OpenAI / AI Foundry,
Managed HSM, App Configuration, API Management, ML workspaces) keep their names
reserved afterwards, so a retry collides with its own leftovers.

This is what
[`Invoke-MhhDeploymentWithRegionFallback`](#invoke-mhhdeploymentwithregionfallback)
uses internally. Call it directly only if you tear an RG down outside that
helper. It works against the current Az context, which the platform has already
pointed at the lab's subscription.

**It deletes everything in the group**, so use it only on a resource group your
lab owns. It first clears what normally blocks a clean redeploy — resource
locks, backup vaults, Log Analytics workspaces and Fabric capacities — then
deletes the group and purges the soft-deleted names it held.

```powershell
$teardown = Remove-MhhResourceGroup -ResourceGroupName $ResourceGroupName
if (-not $teardown.ManifestCaptured -or $teardown.Errors.Count -gt 0 -or $teardown.SoftDeletedResidual.Count -gt 0) {
  $teardown.Errors | ForEach-Object { Write-Warning $_ }
  throw "Cleanup was incomplete. Remaining soft-deleted resources: $($teardown.SoftDeletedResidual -join ', ')"
}
```

| Parameter | Description |
| --- | --- |
| `ResourceGroupName` (`string`, required) | The resource group to tear down. Owned entirely by this cmdlet. |
| `SubscriptionId` (`string`) | Defaults to the current Az context's subscription. |
| `CleanupTimeoutSeconds` (`int`, 60-3600) | How long to wait for the group to disappear before retrying the delete. Default `600`. |
| `CleanupRetryBudget` (`int`, 0-5) | Extra delete attempts when the group is slow to disappear. Default `2`. |
| `PurgeVerifyTimeoutSeconds` (`int`, 0-1800) | How long to wait for purged names to actually become free. Default `180`, `0` disables the check. |
| `SkipSoftDeletePurge` (`switch`) | Delete the RG but leave soft-deleted names reserved. Off by default. |

**Return value:** a hashtable. The fields worth acting on:

| Field | Type | Description |
| --- | --- | --- |
| `Existed` | `bool` | `$false` when there was nothing to delete. |
| `ManifestCaptured` | `bool` | `$false` means the resource list could not be read, so the name purge is incomplete. |
| `SoftDeletedResidual` | `array` | Names that are *still* reserved and **will** collide if you redeploy them. |
| `Errors` | `array` | Non-fatal problems along the way. |

It also returns `ResourceGroupName` and counters for what was cleaned up
(`LocksRemoved`, `VaultsDrained`, `WorkspacesPurged`, `SoftDeletedPurged`,
`Fabric*`).

A delete that never completes throws; most other problems are collected in
`Errors` so the remaining steps still run. Check `Errors` and
`SoftDeletedResidual` before you redeploy the same names, and keep per-lab
resource names unique inside the subscription.

## Authoring guidelines

- **Write for exactly one lab.** Your script is executed once per participant in
  its own process, with `$AllowedEntraUserIds` already narrowed to the precreated Entra user ID(s).
- **Make it scalable.** Your script runs a lot of times in parallel, so avoid global state or pulling stuff from the internet.
  This might work for a single lab deployment, but will likely fail when 50 labs are being deployed at the same time.
  Put everything you need in the `labautomation` folder or at least ensure that you pull e.g. images from a source, that can handle the concurrency without throttling or failing.
- **Be idempotent.** The platform may re-invoke your script if a deployment has failed.
  "Idempotent" here means a re-run converges to the same working lab,
  not that it produces byte-identical values. Use
  `-ErrorAction SilentlyContinue` + `if (-not …)` patterns, or
  `New-AzResourceGroupDeployment` with the same deployment name. For generated
  secrets, see [Passwords and re-runs](#passwords-and-re-runs).
- **Prefer `Invoke-MhhDeploymentWithRegionFallback` for RG-scoped Bicep/ARM deployments.**
  It handles initial RG reuse, conditional recreation, Owner assignment, region fallback, and
  failure classification for you; see
  [the helper docs](#invoke-mhhdeploymentwithregionfallback).
- **Use `Remove-MhhResourceGroup` for explicit lab RG teardown.**
  Plain resource-group deletion can leave resources that block redeployment:
  backup vaults block the delete, and soft-deletable resources (Key Vault,
  Cognitive Services / AI Foundry, Managed HSM, App Configuration, APIM, ML
  workspaces) keep their names reserved, so recreating the same lab collides
  with its own leftovers. Use [`Remove-MhhResourceGroup`](#remove-mhhresourcegroup) instead, and re-grant
  `Owner` to `$AllowedEntraUserIds` after you recreate the group; see [Cleaning up](#cleaning-up).
- **Let `Invoke-MhhDeploymentWithRegionFallback` own Bicep/ARM retry cleanup.**
  Don't pre-delete a reusable RG on every run, and keep your resource names
  stable and unique per lab.
- **Prefer Bicep/ARM over OpenTofu.** OpenTofu is supported, but it has three major drawbacks in the environment:

   1. OpenTofu state does not survive a rescheduled deployment,
   2. OpenTofu has currently no region-fallback or failure-classification helper.
  3. A running OpenTofu process cannot be refreshed by the wrapper. With workload identity, a command that outlives its credential can fail with `AADSTS700024` and leave partial resources.

   If you do use it, **never shell out to `tofu` directly, always use  `Invoke-MhhTofuCommand`**; a bare `tofu` misses the isolated working directory,
  the authentication and the credential refresh. See
  [Deploying with OpenTofu](#deploying-with-opentofu).
- **Honour `$PreferredLocation`, but skip unsupported regions.** Iterate
  through `$PreferredLocation` in order and pick the first region that
  supports every Azure service your lab needs. If you have to skip a region,
  emit a `Write-Warning` so the operator can see *why* the lab landed in a
  fallback region. If none of the preferred regions work, `throw` with a clear
  message. Never hardcode regions, and never silently ignore the list. If your
  script declared `$PreferredLocation` as a comma-separated string, split it
  before handing it to the region-fallback helper.

  ```powershell
  $location = $null
  foreach ($candidate in $PreferredLocation) {
      # Replace with your own probe, e.g. Get-AzComputeResourceSku,
      # Get-AzLocation, or a service-specific availability check.
      if (Test-MyLabRegionSupported -Location $candidate) {
          $location = $candidate
          break
      }
      Write-Warning "Skipping region '$candidate': required services are not available there."
  }
  if (-not $location) {
      throw "None of the preferred regions support this lab: $($PreferredLocation -join ', ')"
  }
  ```

- **Scope RBAC to `$AllowedEntraUserIds`.** If you provision additional
  identities (managed identities, service principals, etc.) and want the user
  to manage them, grant the user access explicitly.
- **Keep any single command under ~90 minutes.** Total script runtime is
  unlimited, but a command that is already running holds the credential it
  started with. Split long deployments into phases and call
  [`Update-MhhToken`](#update-mhhtoken) between them.
- **Use a bounded poll for long ARM deployments.** See the
  [submit-and-poll example](#keeping-credentials-alive-in-long-running-scripts).
  The Azure CLI equivalent uses `--no-wait`, with `2>$null` in place of
  `-ErrorAction SilentlyContinue`:

  ```powershell
  $name = "lab-$(Get-Date -f yyyyMMddHHmmss)"
  az deployment group create --name $name --resource-group $ResourceGroupName --template-file $t --no-wait

  do {
      Start-Sleep -Seconds 30
      Update-MhhToken | Out-Null
      $state = az deployment group show --resource-group $ResourceGroupName --name $name --query provisioningState -o tsv 2>$null
  } while ($state -notin 'Succeeded', 'Failed', 'Canceled')
  ```

  For subscription-scoped templates use `New-AzDeployment -AsJob` or
  `az deployment sub create --no-wait`. Either way, poll the *deployment* rather
  than the PowerShell job, and remember this plain Az path gives you no region
  fallback and no cleanup.
- **Keep total runtime reasonable.** The same script runs concurrently for every
  participant; long synchronous deployments slow down the whole event start.
- **Do not call `Connect-AzAccount`, `Set-AzContext` or `az login`.** The platform
  manages authentication and subscription context, and keeps each lab's Azure
  CLI login isolated for you.


