# Base infrastructure (facilitator only)

Terraform provisions one isolated participant resource group per index. Every group contains two
independent Windows Server 2025 legacy workstations before the workshop starts:

| Stack | VM | Native database | Application |
| --- | --- | --- | --- |
| .NET | `vm-dotnet-userNNN` | SQL Server 2022 Express | .NET SDK 8.0.424 catalog on port 5000 |
| Java | `vm-java-userNNN` | PostgreSQL 18.6-1 | Microsoft OpenJDK 17.0.20+8 catalog on port 8080 |

The VMs share `rg-userNNN`, `vnet-userNNN`, the `vms` subnet, and each has its own public IP,
`nsg-userNNN`, `nat-userNNN`, and `pip-nat-userNNN`. They have separate NICs, dynamic private
addresses, VM resources, Premium OS disks, managed identities, and Custom Script Extensions.
Either VM can be stopped or deallocated without changing the other.

## Frozen provisioning

The Windows image is exactly `MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:26100.7456.251206`.
Application content comes from an immutable commit that **you must set for every delivery**:
`source_commit` has no default, and the historical `fd298de6…` pin is rejected outright
because its tree carries none of the current chapters. Terraform also rejects branch, tag,
short-SHA, and other mutable source values, and provisioning fails loudly if the downloaded
archive does not carry the application sources and challenge folders. See "Re-pin the VM source
commit" in [the facilitator guide](../docs/Facilitator.md).

`baseInfra/scripts/provision-vm.ps1` and a generated per-stack secret payload are embedded as a VM
custom-data bundle. Azure stores the decoded bundle under the SYSTEM/Administrators-only
`C:\AzureData` boundary. The Custom Script Extension runs only the secret-free encoded
`bootstrap-provision-vm.ps1`. Terraform gzip-compresses that maintained script into a short wrapper
and rejects a rendered command above 7,800 characters. The bootstrap reads the bundle as data,
writes the payload to
`C:\MicroHack\secrets` and a clean provisioner to `C:\AzureData`, applies restrictive ACLs, clears
`CustomData.bin`, and only then launches Windows PowerShell on the clean script. No payload value is
PowerShell source, a process argument, or a log field. The provisioner verifies each locked digest
and Authenticode publisher before running an installer. It does not use `winget`, `latest`,
package-manager fallback chains, or raw branch URLs.

Both VMs receive pinned VS Code, Azure CLI, uv, uv-managed Python 3.12.10, GitHub Copilot,
and the unified signed GitHub Copilot modernization extension. The .NET VM additionally receives
the pinned .NET upgrade companions and the self-contained SqlPackage 170.4.83.3 Windows archive
used by the Challenge 1 BACPAC export.
Provisioning verifies the archive SHA-256, the extracted executable's Microsoft Authenticode
publisher, and its exact version before adding its directory to machine PATH.
The Java VM receives the pinned Java upgrade companion, Microsoft OpenJDK, and the
checksum-pinned Maven Wrapper workflow.

Both VMs also receive pinned Git for Windows 2.55.0.windows.5, verified by SHA-256 and by its
`Johannes Schindelin` Authenticode publisher exactly like every other pinned tool. Git is present
because both GitHub Copilot Challenge 1 paths record their work as a commit and read it back with
`git rev-parse HEAD`. Because the source arrives as a signed archive rather than a clone, it has no
history of its own, so provisioning initializes a repository in `C:\MicroHack\source` holding a
single baseline commit. A participant's first commit is therefore their own modernization work.
That local commit is intentionally unrelated to the published commit SHA: upstream provenance stays
in `C:\MicroHack\source\.source-commit`, which is the only value that may be quoted as archive
provenance.

Container images are never built on the VM. Every image build in the workshop runs server-side
through `az acr build`, so no Docker daemon is installed or required.

## Facilitator preflight

Work through the delivery checklist in
[the facilitator guide](../docs/Facilitator.md) before this component gate. The two-VM
baseline is consumed by [Challenge 0](../challenges/ch00.md).

Prerequisites:

- Terraform 1.13.3 and PowerShell 7
- Azure CLI 2.80.0 authenticated to the target subscription
- subscription permissions for resource groups, networking, public IPs, VMs, role assignments,
  provider registration, and optional Entra user creation

From the repository root, run the quota and cost gate for the exact participant count, regions,
VM size, and disk size:

```pwsh
./baseInfra/scripts/preflight-capacity.ps1 `
  -SubscriptionId '<facilitator-provided-subscription-guid>' `
  -Locations @('swedencentral', 'germanywestcentral') `
  -ParticipantCount 10 `
  -VmSize 'Standard_D2as_v5' `
  -OsDiskSizeGiB 127 `
  -MaximumEstimatedMonthlyCostUsd 3000
```

The command fails when the SKU is restricted or regional, VM-family, VM-count, Premium managed
disk, or Standard public IP quota cannot cover the per-participant footprint. Every
participant gets two Windows VMs, two Premium OS disks, and two Standard public IP addresses -- one
per VM -- and all of those are counted. Quota metrics or retail meters that Azure does not
return are reported in `quotaMetricsUnavailable` and `pricesUnavailable` instead of being dropped
silently.

Download the immutable archive once to record the digest that every VM will enforce. Set `$commit`
to the exact 40-hex SHA you pushed for this delivery — take it from `git rev-parse HEAD` after the
push and confirm the published archive really contains `dotnet/`, `java/`, `data/`, and the flat challenge guides in
`challenges/`, following "Re-pin the VM source commit" in
[the facilitator guide](../docs/Facilitator.md). The placeholder below is not a commit and the
snippet does nothing until you replace it:

```pwsh
$commit = '<facilitator-provided-40-character-lowercase-commit>'   # placeholder: see docs/Facilitator.md
$archive = Join-Path $env:TEMP "$commit.zip"
Invoke-WebRequest `
  -Uri "https://github.com/CZSK-MicroHacks/MicroHack-AppInnovation/archive/$commit.zip" `
  -OutFile $archive
$env:TF_VAR_source_archive_sha256 = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Remove-Item $archive
```

The commit must exist in the public repository before this command or VM provisioning can succeed,
and Terraform rejects the historical `fd298de6…` pin, so it is never a valid substitute here.

## Initialize, plan, and apply

Copy `baseInfra/terraform/config.tfvars.example` to a git-ignored local file and set only non-secret
deployment values. Supply secrets and preflight acknowledgement through the facilitator process:

```pwsh
Set-Location baseInfra/terraform
$env:TF_VAR_admin_password = '<strong-facilitator-secret>'
$env:TF_VAR_capacity_preflight_confirmed = 'true'

Copy-Item backend.hcl.example backend.hcl   # then edit it; see docs/Facilitator.md
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file local.tfvars -out tfplan
terraform apply tfplan
```

Terraform generates a separate initial password for every participant Entra user and forces a
change at first sign-in, so there is no shared user password to set. Read the credentials with
`terraform output -json entra_user_credentials` and hand out one row per participant privately.

Do not commit `.tfvars`, plan, or state files. Terraform state contains the Windows administrator
password, generated per-environment database passwords, generated performance API keys, VM custom
data, and protected extension settings. VM custom data is ACL-restricted on Windows but is not an
encrypted secret store; its safety depends on the encrypted, access-controlled Terraform backend
and administrator-only VM access. Restrict state and administrator access as tightly as the VMs.

## Guided test deployment (facilitator dry run)

`baseInfra/scripts/facilitator-test-deploy.ps1` walks a facilitator through the whole sequence
above in one interactive pass: it reads the subscription and facilitator identity from the
active Azure CLI session, prompts for the remaining inputs, downloads and verifies the source
archive, runs the capacity preflight, then executes init/validate/plan/apply and prints how to
reach every provisioned VM.

```pwsh
az login
az account set --subscription '<subscription-guid>'
./baseInfra/scripts/facilitator-test-deploy.ps1
```

To review what would happen without creating anything, add `-DryRun`. It runs the same
inference, preflight, and plan, then prints a summary of the changes and stops:

```pwsh
./baseInfra/scripts/facilitator-test-deploy.ps1 -DryRun
```

```text
Target subscription : Contoso Workshop (7bc68c68-...)

Totals
  Create      120

By resource type
  Create       82  azurerm_resource_provider_registration
  Create        4  Microsoft.Compute/virtualMachines
  Create        2  Microsoft.Resources/resourceGroups
  ...

Resource groups
  Create     rg-user001
  Create     rg-user002
```

Anything that would be destroyed or replaced is listed separately and highlighted. The dry run
skips the VM password prompt, since no password reaches Azure or state on a plan-only run, and
leaves the saved plan at `baseInfra/terraform/tfplan` for `terraform show tfplan`.

It is a dry-run tool, not a delivery tool. Three defaults differ from a real cohort:

- Terraform state is written to a local file (`~/.microhack/baseinfra-test/terraform.tfstate`
  by default) through a generated `backend_override.tf`, instead of the encrypted remote
  backend. State still holds generated database passwords and performance API keys, so the
  directory is created with owner-only permissions and must stay private.
- `manage_entra_users` defaults to `false`, so no participant signs in to Azure.
- The VM administrator password defaults to a well-known throwaway value.

Useful switches: `-DryRun` stops after the plan, `-VarFile <name>` writes to a different tfvars
file (an existing one is backed up before it is overwritten), `-StatePath <path>` relocates the
state file, and `-SkipPreflight` skips the quota and cost gate. The script never applies without
showing the plan first, and it prints the matching `terraform destroy` command when it finishes.

Verify the script's input handling and both source-archive layout checks without touching Azure:

```pwsh
pwsh tests/baseInfra/facilitator-test-deploy.helpers.tests.ps1
```

## Outputs and access

The root outputs include:

- `dotnet_vm_names` and `java_vm_names`
- `vm_names_by_environment`
- `private_ip_addresses_by_environment`
- `resource_group_names`, `vnet_names`, and region distribution
- `deployment_footprint` with doubled VM, vCPU, OS-disk, and disk-GiB totals

Connect over RDP by requesting **Just-in-Time VM access** in the Azure Portal — the NSG
ships with no inbound rules, and standing 3389 rules are removed by tenant governance.
Participants do this themselves in [Challenge 0](../challenges/ch00.md) for whichever
VM matches the stack they chose. Both VMs stay running for the duration of the workshop; the
facilitator can follow the [ch00 solution](../walkthrough/ch00/README.md) to help anyone stuck.

Power-state changes are bounded to starting or stopping a VM and do not authorize
replacement or deletion.

## Provisioning status and diagnostics

Provisioning succeeds only after `/healthz`, `/readyz`, one canonical lowercase UUID image, the
198/20/198 manifest, and the stack-native database counts pass locally. Inspect these files from
the selected VM:

```pwsh
Get-Content C:\MicroHack\status\dotnet-smoke.json
Get-Content C:\MicroHack\status\java-smoke.json
Get-Content C:\MicroHack\logs\provision-dotnet.log
Get-Content C:\MicroHack\logs\provision-java.log
Get-Content C:\MicroHack\logs\dotnet-app.log
Get-Content C:\MicroHack\logs\java-app.log
Get-ScheduledTask -TaskName 'MicroHack-*'
```

Only the matching stack files exist on each VM. SQL Server/PostgreSQL services and the
`MicroHack-dotnet`/`MicroHack-java` startup tasks are automatic. Each startup script waits up to
five minutes for a successful native database query before launching the application. Every probe
has native connection/query timeouts plus a ten-second process ceiling; a hung client is terminated
by its exact PID. A sanitized terminal failure is appended to the matching documented app log
before Task Scheduler retries it. Ordinary VM restarts do not reseed duplicate records or require
student setup; the application import paths remain transactional and insert-new/idempotent.

Changing `source_commit` updates the extension force tag and reruns verified provisioning in
place. Every rerun first disables the matching task to suppress queued restarts, stops a running
instance, and identifies its application only by exact parsed DLL/JAR arguments before termination.
It then rehashes the cached/downloaded archive, extracts a clean source tree, builds into staging,
and atomically swaps the completed source and application directories. An interrupted application
swap restores `.previous` before another attempt. Editing either provisioning script replaces both
VMs in each affected participant module because Azure VM custom data is immutable. The replacement
hash covers both scripts, the bundle format, and the gzip transport version; review that replacement
plan carefully. To deliberately rerun one stack without replacing its VM:

```pwsh
terraform apply `
  -replace='module.user_environment["1"].azapi_resource.vm_setup["dotnet"]'
```

## Provider registration and cleanup boundary

Provider registration explicitly includes ACA and SRE Agent (`Microsoft.App`), ACR
(`Microsoft.ContainerRegistry`), Azure SQL, PostgreSQL, Monitor, and Defender. The registration
resources use `prevent_destroy = true`; Terraform must never unregister shared subscription
providers during participant cleanup.

To destroy participant infrastructure while retaining the registrations, detach only the
registration module from this state first:

```pwsh
terraform state rm 'module.resource_providers[0]'
terraform destroy -var-file local.tfvars
```

Review the destroy plan carefully. Reducing `n`, changing assigned regions, VM size, image, or OS
disk settings can replace resources and discard their local ephemeral data.

There is no broad subscription cleanup script. Destroy only the reviewed participant
Terraform state after paid-service cleanup, protected-resource inventory, and explicit
facilitator authorization.
