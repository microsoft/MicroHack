# Facilitator Terraform

This root module uses `azapi` for workshop resources and `azurerm` for authentication and explicit
provider registration. It creates two keyed VM resources per participant:

```text
module.user_environment["1"].azapi_resource.vm["dotnet"]
module.user_environment["1"].azapi_resource.vm["java"]
```

The matching NIC, extension, managed-identity role assignment, generated database password, and
generated performance key use the same `dotnet` or `java` key. The network,
NSG, resource group, and outbound public IP remain single shared resources in that participant
module.

## Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `n` | `5` | Participant environments; creates `n * 2` VMs and OS disks |
| `locations` | required | Unique regions assigned round-robin |
| `subscription_id` | required | Target Azure subscription |
| `admin_username` | `azureuser` | Local administrator name on both VMs |
| `admin_password` | none, sensitive | Set with `TF_VAR_admin_password` |
| `vm_size` | `Standard_D2as_v5` | Size used by both VMs |
| `vm_vcpus` | `2` | Footprint value confirmed by preflight |
| `os_disk_size_gb` | `127` | Separate Premium OS disk size for each VM |
| `source_commit` | frozen 40-hex commit | Immutable application/data source |
| `source_archive_sha256` | required | Reviewed immutable archive digest |
| `capacity_preflight_confirmed` | `false` | Blocks resource creation until preflight succeeds |
| `manage_entra_users` | `true` | Creates participant Entra users when enabled |
| `entra_user_domain` | empty | Required when Entra user creation is enabled |
| `entra_user_password_length` | `24` | Length of the per-user initial password Terraform generates |
| `manage_azure_resources` | `true` | Enables participant infrastructure |
| `manage_sub_providers` | `true` | Enables explicit provider registration |
| `enable_defender_foundation` | `false` | Opts in to the frozen paid Defender plans and subscription budget |
| `defender_facilitator_authorized` | `false` | Required facilitator approval for the paid foundation |
| `defender_budget_name` | `mh-defender-workshop` | Stable subscription budget name |
| `defender_budget_amount` | `0` | Explicit positive amount required when enabled |
| `defender_budget_start_date` | empty | First day of the current month through twelve months ahead at midnight UTC |
| `defender_budget_end_date` | empty | Explicit later RFC 3339 budget end required when enabled |
| `defender_budget_notification_emails` | empty | One or more facilitator recipients required when enabled |

No secret belongs in `config.tfvars.example` or a committed `.tfvars` file. Generated secrets,
VM custom data, and protected extension settings are still present in Terraform state. VM custom
data is restricted to SYSTEM/Administrators after Windows provisioning but is not an encrypted
secret store, so use an encrypted, access-controlled remote backend and tightly restrict VM
administrator access.

## Participant sign-in credentials

Terraform generates one `random_password` per participant and sets `force_password_change = true`,
so every participant receives a different initial password and must change it at first sign-in.
There is no shared workshop password to leak or reuse.

Read the credentials only when you are ready to hand them out:

```pwsh
terraform output -json entra_user_credentials | ConvertFrom-Json
```

Distribute one row per participant over a private channel. Do not paste the whole map into a chat
room: the participant user principal names are predictable (`userNNN@<domain>`), so one leaked
password is enough to sign in as somebody else.

## Remote state

State holds every generated secret in clear text — participant passwords, database passwords, and
performance keys — so a local `terraform.tfstate` file is not acceptable for a real cohort. This
module declares a partial `azurerm` backend; you supply the storage account at init time.

Bootstrap the state container once per subscription, then:

```pwsh
Copy-Item backend.hcl.example backend.hcl   # backend.hcl is git-ignored
# edit backend.hcl with your storage account name
terraform init -backend-config=backend.hcl
```

The full bootstrap procedure, including the storage-account settings that make the container safe
to hold secrets, is in [`../../docs/Facilitator.md`](../../docs/Facilitator.md).

Validation and formatting do not need a backend:

```pwsh
terraform init -backend=false
terraform validate
```

## Commands

Run the exact preflight and source digest procedure in [`../README.md`](../README.md), then:

```pwsh
Set-Location baseInfra/terraform
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file local.tfvars -out tfplan
terraform apply tfplan
```

Do not use `terraform apply -auto-approve` for the facilitator environment. Review the doubled
compute/disk footprint, source digest, provider registrations, and all replacements in the saved
plan.

For a dependency-safe validation and reviewed plan from the repository root, run:

```pwsh
terraform -chdir=baseInfra/terraform init -backend=false -lockfile=readonly
terraform -chdir=baseInfra/terraform validate
terraform -chdir=baseInfra/terraform plan -var-file=local.tfvars -out=tfplan
terraform -chdir=baseInfra/terraform show tfplan
```

These commands do not apply the plan. Keep `enable_defender_foundation=false` for ordinary participant
infrastructure plans.

Useful outputs:

```pwsh
terraform output dotnet_vm_names
terraform output java_vm_names
terraform output vm_names_by_environment
terraform output private_ip_addresses_by_environment
terraform output deployment_footprint
```

## Defender for Cloud facilitator foundation

The foundation creates the five `Microsoft.Security/pricings@2024-01-01` resources listed in
`defender.tf`, plus one
`Microsoft.Consumption/budgets@2023-11-01` subscription budget. Participant users retain their existing
resource-group Owner permission for modernization and additionally receive the built-in Security Reader
role on only their assigned resource group. Paid-plan and policy administration remain subscription-level
facilitator responsibilities.

The Defender plans incur charges. Before a reviewed plan may contain them, an authorized facilitator must:

1. Use a dedicated workshop subscription and capture the complete current Defender pricing state, including
   pricing tier, subplan, enforce value, and extensions for every plan that cleanup could affect.
2. Complete the Owner-only **Serverless Containers** portal preflight. The pricing API does not expose that
   switch, so Terraform intentionally does not model it.
3. Set `enable_defender_foundation=true`, `defender_facilitator_authorized=true`, a positive
   `defender_budget_amount`, a midnight-UTC start on the first day of the current month through
   twelve months ahead, a later RFC 3339 end date, and at least one facilitator email in
   `defender_budget_notification_emails`.
4. Review the saved plan before any separately authorized apply.

Enable the foundation far enough ahead of the workshop to pre-warm ACA and ACR coverage. Full Serverless
Containers coverage can take up to 24 hours to appear; live findings and recommendations are asynchronous.

Terraform does not automate Defender cleanup or restore prior settings. After the workshop, an authorized
facilitator must capture the pre-cleanup inventory, restore every prior pricing/subplan/enforce/extension
value and the Serverless Containers portal state, verify the restored pricing state, capture the
post-cleanup inventory, and check the subscription cost query. Cost data may lag, so record the query time and
repeat cost verification until workshop charges have stopped.

`Microsoft.Security/pricings@2024-01-01` DELETE is **Valid only for resource scope**; it cannot remove
these subscription pricing objects. Terraform therefore creates the budget before changing any paid plan
and protects every pricing instance with `prevent_destroy`. Do not disable the foundation or destroy its
state while paid pricing remains. Only after the solution's authorized restoration and verification
complete, detach the restored subscription pricing objects from Terraform state without changing Azure:

```pwsh
terraform state rm 'azapi_resource.defender_pricing'
```

The facilitator may then set `enable_defender_foundation=false` and review a plan that removes the budget.

## Immutable Custom Script Extension

The provisioner and a generated per-stack secret payload are embedded in each VM's custom data
instead of downloaded from a branch. Azure decodes the data bundle under the
SYSTEM/Administrators-only `C:\AzureData` directory. The extension command is stored only in
`protectedSettings` and contains a secret-free encoded bootstrap. Before any provisioner
execution, a short wrapper decodes the Terraform `base64gzip` payload with .NET
`MemoryStream`/`GZipStream`/`StreamReader`, dot-sources the decompressed secret-free bootstrap, and
calls it with only stack/source metadata. The bootstrap reads the bundle as data, writes a protected
payload and clean script, clears `CustomData.bin`, and launches a new Windows PowerShell process
against only the clean script. Payload values never become PowerShell source, command arguments, or
logs. A lifecycle precondition rejects an entire rendered CSE command above 7,800 characters.
Installers
receive database setup secrets through short-lived protected response/option files; `sqlcmd` and
`psql` authenticate through `SQLCMDPASSWORD` and `PGPASSWORD`, never password command arguments.
Application/data content uses:

```text
https://github.com/CZSK-MicroHacks/MicroHack-AppInnovation/archive/<40-hex-commit>.zip
```

`source_archive_sha256` is verified before every expansion, including cached archives. Each run
uses a clean staging extraction and atomically swaps the source tree rather than trusting a prior
mutable extraction. Every tool and database installer is downloaded from a
pinned URL with SHA-256 digest verification, plus Authenticode publisher verification where
applicable.

VM image version, .NET, SQL Server Express, go-sqlcmd, self-contained Windows SqlPackage,
Microsoft OpenJDK, PostgreSQL, Maven, VS Code, Azure CLI, uv, Python, and VS Code extension
versions are pinned. SqlPackage installation verifies the locked archive digest, extracted
executable publisher, and exact version without requiring another .NET runtime. There are no
raw branch URLs, `latest` versions, or mutable package-manager fallbacks.

VM custom data cannot be updated in place. A `terraform_data.provisioner` replacement trigger makes
any bootstrap, provisioner, bundle-format, or transport-version change replace the two VMs rather
than attempt an invalid Azure update. The same combined digest drives the extension force tag.
Changing only `source_commit` reruns each extension in place and reuses the already-separated
protected local files.

## Independent operation

Each database is a local automatic Windows service. Each application is run by an automatic
scheduled task (`MicroHack-dotnet` or `MicroHack-java`) whose startup script requires a successful
native database query within five minutes before launching the app. Native connection/query
timeouts and an exact-PID process deadline prevent either client from hanging the task; final
sanitized failures are written to the stack app log before retry. A provisioner rerun disables the
task before stopping it, matches only exact parsed DLL/JAR arguments, recovers an interrupted
`.previous` directory, publishes to staging, and atomically swaps the completed output. Task
registration explicitly re-enables it before start. Provisioning creates a stack-specific smoke
marker only after the app, liveness, readiness, canonical image, canonical manifest counts, and
native database counts pass.

Deallocating `vm-dotnet-userNNN` does not affect `vm-java-userNNN`, and vice versa. The shared
VNet, subnet, and NSG remain available while either VM is stopped. Each VM keeps its own static
public IP address across a stop/start cycle, so the URL a participant bookmarked stays valid.

## Provider registration lifecycle

The AzureRM provider sets `resource_provider_registrations = "none"`. The registration module owns
the approved namespace list and uses `prevent_destroy = true` to preserve the subscription-wide
boundary. Before participant cleanup, remove that module from this state without unregistering it:

```pwsh
terraform state rm 'module.resource_providers[0]'
terraform destroy -var-file local.tfvars
```

Use `import_existing_providers.ps1` when adopting existing registrations into a new state.
