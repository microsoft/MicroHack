# Facilitator guide

This is the practical runbook for delivering the MicroHack. Keep it boring: provision the
baseline VMs, make sure everyone can sign in, make the paid-service decisions before the
room arrives, and help participants build their own Azure target with GitHub Copilot.

On the day, use the printable [day-of card](DayOfCard.md). For schedule trade-offs, see
[the agenda](Agenda.md). For budget discussions, see [the cost estimate](CostEstimate.md).

## Delivery shape

- Each participant gets one resource group named `rg-userNNN`.
- That group contains two legacy Windows VMs:
  - `vm-dotnet-userNNN` for .NET 8 Blazor Server + SQL Server 2022 Express.
  - `vm-java-userNNN` for Spring Boot 3 / Java 17 + PostgreSQL 18.
- Participants choose one stack in [ch00](../challenges/ch00.md) and keep it.
- RDP is direct to the VM public IP after requesting **Just-in-Time VM access**. Do not
  add standing inbound 3389 rules.
- From ch01 onward, participants work from source and author their own Bicep with Copilot.
  There is no shared application infrastructure template to deploy for them.
- Challenge 1 has exactly two paths:
  - **A — Modernize with GitHub Copilot**: keep the app, upgrade it, containerize it.
  - **B — Rewrite with GitHub Copilot**: use the legacy app as the specification and
    rebuild from a reviewed PRD and plan.
- Both paths end at the same architecture: Azure Container Apps, a managed database,
  Azure storage for images, Azure Container Registry, and participant-authored IaC.

## Decisions before you book the room

| Decision | Why it matters |
| --- | --- |
| Dedicated Azure subscription | The workshop creates many VMs and may enable paid Defender plans. Do not use a production or shared business subscription. |
| Subscription Owner for the facilitator | Needed before and after the workshop for provider registration, resource groups, role assignments, budgets, and paid-plan changes. Participants only need Owner on their own resource group. |
| Quota and region choice | Count two `Standard_D2as_v5` Windows VMs, two Premium OS disks, and two Standard public IPs per participant. Large cohorts may need multiple regions or subscriptions. |
| GitHub organization | Participants need a place to push code and run Actions. If repos are private and Challenge 3 uses required reviewers, use GitHub Team or Enterprise Cloud. |
| GitHub Copilot licenses | Assign one seat per participant who will use Copilot. Confirm the VS Code extension works before day 1. |
| Paid Defender plans | [ch05-defender](../challenges/ch05-defender.md) is better with Defender CSPM, Containers, Servers Plan 2, SQL, and open-source relational database plans enabled. Get subscription-owner sign-off for cost and cleanup. |
| Azure SRE Agent capacity | [ch06-sre-agent](../challenges/ch06-sre-agent.md) may be per team or facilitator-led. Confirm regional availability, permissions, and hourly agent-unit cost. |
| Budget and teardown owner | Put the destroy date in a calendar. Forgetting teardown costs more than the workshop. |

## Lead time

| When | Work |
| --- | --- |
| T-15 working days | Secure subscription, Owner access, quota approvals, GitHub plan, Copilot seats, paid-service approvals, and teardown owner. |
| T-7 working days | Bootstrap Terraform state, run capacity preflight, prepare the GitHub org, and pin the source commit. |
| T-3 working days | If using paid Defender plans or SRE Agent, enable and test them. Defender findings and coverage are asynchronous; allow at least 24 hours. |
| T-2 working days | Provision participant environments with Terraform from [baseInfra](../baseInfra/README.md). |
| T-1 working day | Smoke-test VMs, JIT RDP, GitHub push, Copilot sign-in, budget alert, and any optional paid-service setup. |
| Day 0 | Print the [day-of card](DayOfCard.md), credentials, resource-group map, and cleanup owner. |

## Facilitator workstation

Run facilitator commands from your own machine with Azure CLI, Terraform 1.13.x,
PowerShell 7, `git`, `curl`, `jq`, `unzip`, `gh`, and `uv`. Do not commit local
`.tfvars`, plans, state files, rosters, passwords, or participant data.

## Bootstrap Terraform remote state

Terraform state contains generated passwords and keys. Use an encrypted, access-controlled
remote backend instead of a local `terraform.tfstate`.

```bash
LOCATION=swedencentral
RG=rg-microhack-tfstate
SA=stmhtfstate$RANDOM$RANDOM

az group create --name "$RG" --location "$LOCATION"
az storage account create \
  --name "$SA" --resource-group "$RG" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --https-only true
az storage container create --name baseinfra --account-name "$SA" --auth-mode login
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "$(az storage account show --name "$SA" --resource-group "$RG" --query id -o tsv)"
```

Then edit `baseInfra/terraform/backend.hcl` from its example and run `terraform init` from
`baseInfra/terraform`.

## Run capacity preflight

Run the PowerShell preflight for the exact participant count, VM size, disk size, and
regions you will use:

```pwsh
./baseInfra/scripts/preflight-capacity.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -Locations @('swedencentral', 'germanywestcentral') `
  -ParticipantCount 30 `
  -VmSize 'Standard_D2as_v5' `
  -OsDiskSizeGiB 127 `
  -MaximumEstimatedMonthlyCostUsd 20000
```

Check any `quotaMetricsUnavailable` or `pricesUnavailable` entries manually in the Azure
Portal. Confirm JIT VM access is available; it is the most likely day-one blocker.

## Prepare GitHub

Follow the helper in [baseInfra GitHub setup](../baseInfra/github/README.md).

```bash
cd baseInfra/github
cp users.yaml users.local.yaml
# edit users.local.yaml with real GitHub handles; never commit it
USERS_FILE=users.local.yaml uv run python main.py
```

Before the workshop:

- Assign Copilot seats.
- Make sure each participant can find their repository URL.
- For Challenge 3, create or test `staging` and `production` GitHub environments on one
  repo and confirm required reviewers are available for your plan and visibility.
- From one provisioned VM, push a throwaway commit to prove browser sign-in and SSO work.

## Re-pin the source commit

The VMs download a GitHub archive for the exact commit you set. Push the commit first,
then record both the SHA and archive digest.

```bash
COMMIT=$(git rev-parse HEAD)
REPO=CZSK-MicroHacks/MicroHack-AppInnovation
curl -fsSL -o source.zip "https://github.com/$REPO/archive/$COMMIT.zip"
unzip -Z1 source.zip | sed 's|^[^/]*/||' | sort | grep -E \
  '^(README.md|challenges/ch01.md|challenges/ch01-A.md|challenges/ch01-B.md|dotnet/README.md|java/README.md|baseInfra/README.md)$'
shasum -a 256 source.zip
rm source.zip
```

Set `source_commit` in your Terraform tfvars and set `TF_VAR_source_archive_sha256` to the
64-character digest.

The pin is deliberately local: `local.tfvars` is git-ignored, and the tracked
`config.tfvars.example` ships an empty `source_commit`. If you just want a known-good
starting point, this pair was verified end to end — provisioned onto both VMs, digest and
content guards passing, apps healthy afterwards:

```hcl
source_commit         = "b1846d144b3084d50a689dcfcfe084b54fa16f53"
source_archive_sha256 = "13a2bd207b9236a220f37b334da5102271163b172cf0d1bcf6ead44352e57c0e"
```

That commit is on `main`. Pin to a commit that is merged rather than one that only exists
on a feature branch, so the archive stays reachable after the branch is deleted. Re-run the
steps above for any newer commit — the digest changes with the tree.
The known-good pin above predates the flat challenge layout: it remains usable for existing
deliveries, but VMs will not receive the new layout until you pin a merged layout commit.

> The provisioner refuses an archive that does not contain `data/manifest.json`, `dotnet/`,
> `java/` and `challenges/ch01.md` (or the legacy `challenges/ch01/` directory for
> previously pinned archives). That guard only proves the archive *is* a workshop tree,
> not that it is the current one, so a stale pin can still install an old workshop silently.
> Re-pin after publishing this layout change and whenever the content changes.

Changing the pin updates the VM extensions in place — no VM is rebuilt, and provisioning
leaves participant work alone when the VM's `.source-commit` marker already matches.

## Provision participants

Copy `baseInfra/terraform/config.tfvars.example` to a git-ignored local tfvars file and
set `n`, `locations`, `subscription_id`, `entra_user_domain`, `source_commit`, and the
facilitator identity fields. Supply secrets through environment variables.

```bash
cd baseInfra/terraform
export TF_VAR_admin_password='<strong-facilitator-secret>'
export TF_VAR_capacity_preflight_confirmed=true
export TF_VAR_source_archive_sha256='<archive-sha256>'
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file local.tfvars -out tfplan
terraform show tfplan
terraform apply tfplan
```

Do not use `-auto-approve`. Read the generated participant credentials only when you are
ready to hand them out privately:

```bash
terraform output -json entra_user_credentials | jq .
terraform output resource_group_names
terraform output public_ip_addresses_by_environment
```

## T-1 smoke checks

| Check | How |
| --- | --- |
| VM provisioning | On a VM, read `C:\MicroHack\status\dotnet-smoke.json` and `C:\MicroHack\status\java-smoke.json`. The chosen stack must pass health, readiness, image, catalog-count, and database checks. |
| Source archive | `type C:\MicroHack\source\.source-commit` equals the commit you pinned. |
| JIT RDP | Request access through the portal and connect to one VM per region. If JIT is missing, enable the Defender for Servers prerequisite before the workshop. |
| Application before-state | Open `http://localhost:5000` on the .NET VM or `http://localhost:8080` on the Java VM. Search, filter, open a detail page, and load an image. |
| GitHub push | Push one harmless commit from a provisioned VM to a scratch repo in the workshop org. |
| Copilot | Sign in from a participant-like account and confirm Copilot Chat works in VS Code. |
| Budget | Confirm the budget exists and alerts go to a named human. |
| Paid services | If using Defender or SRE Agent, confirm the paid plans/resources are intentional and documented. |

## Challenge notes

| Challenge | Facilitator focus | Common saves |
| --- | --- | --- |
| [ch00](../challenges/ch00.md) | Keep it to stack choice and the legacy before-state. Help with JIT and RDP. | JIT expired: request access again. Wrong VM: check `vm-dotnet-userNNN` versus `vm-java-userNNN`. App external URL missing: expected; browse inside RDP. |
| [ch01](../challenges/ch01.md) → [A](../challenges/ch01-A.md) / [B](../challenges/ch01-B.md) | Explain the two paths, have each person open only their own, and split tables so teams can compare. Do not hand out a template; participants author Bicep, Dockerfiles, and deployment steps with Copilot. | Check stale env vars, database firewall rules, ACR pull identity, Azure Files/image paths, and the fact that the VM has no Docker daemon. Use `az acr build`. |
| [ch02](../challenges/ch02.md) | Watch pressure move from Container Apps replicas to the database. Azure Load Testing is fine for `GET /perftest/catalog`; Playwright is better for browser/WebSocket flows. | If replicas do not move, check max replicas and HTTP concurrency. If the database stays flat, verify the test hits the performance endpoint with the API key. |
| [ch03](../challenges/ch03.md) | Make sure the GitHub plan supports required reviewers for your repo visibility. Push participants toward OIDC with a managed identity. | No approval prompt usually means the environment rule is unavailable or attached to the wrong job/environment. |
| [ch04](../challenges/ch04.md) | Wire the Container Apps OpenTelemetry collector to Application Insights without adding a vendor SDK. | Generate traffic, wait a few minutes, and restart the revision after collector changes. |
| [ch05-defender](../challenges/ch05-defender.md) | Subscription-owner approval is required before paid Defender plans are enabled. Participants inspect posture; facilitators own subscription-wide changes. | Focus on ACR admin, HTTPS-only ingress, database public access, and VM management exposure through JIT. Empty blades can mean findings have not arrived yet. |
| [ch06-sre-agent](../challenges/ch06-sre-agent.md) | Decide per-team agent versus facilitator-led before the day. Use Review mode, not autonomous remediation. Only an SRE Agent Administrator approves writes. | Keep the failure small and reversible: bad DB host, bad secret, stopped database, or a bad revision promoted for the drill. |
| [ch07-enterprise](../challenges/ch07-enterprise.md), [ch07-innovation](../challenges/ch07-innovation.md), [wrap-up](../challenges/wrapup.md) | ch07 is optional. Drop it before cutting the wrap-up. | The wrap-up is what participants can take back to their manager. |

## Reset one participant

Run these from `baseInfra/terraform` and replace `7` with the participant index.

Rerun provisioning for one stack without replacing the VM:

```bash
terraform apply -var-file local.tfvars \
  -replace='module.user_environment["7"].azapi_resource.vm_setup["dotnet"]'
```

Rebuild one VM completely; this destroys local work on that VM:

```bash
terraform apply -var-file local.tfvars \
  -target='module.user_environment["7"]' \
  -replace='module.user_environment["7"].azapi_resource.vm["java"]'
```

Reissue one participant password:

```bash
terraform apply -var-file local.tfvars \
  -replace='module.entra_users["7"].random_password.this'
terraform output -json entra_user_credentials | jq '."7"'
```

Start a VM that was stopped by mistake:

```bash
az vm start --resource-group rg-user007 --name vm-dotnet-user007
```

Always finish targeted Terraform work with `terraform plan -var-file local.tfvars` and read
the drift before doing anything else.

## Clean up after yourself on a participant VM

If you use a named run-command, delete it. A pending named command blocks later commands.
Prefer `az vm run-command invoke` for one-shot checks.

```bash
az vm run-command list -g rg-user007 --vm-name vm-java-user007 --query "[].name" -o tsv
az vm run-command show -g rg-user007 --vm-name vm-java-user007 \
  --run-command-name <name> --instance-view \
  --query "{exec:instanceView.executionState,start:instanceView.startTime}"
az vm run-command delete -g rg-user007 --vm-name vm-java-user007 \
  --run-command-name <name> --yes
```

## Teardown

Do paid and external cleanup before destroying Terraform-managed base infrastructure.

1. Ask participants to save anything they need from their resource group or GitHub repo.
2. Delete Azure SRE Agent resources you created. Stopping an agent is not the same as
   deleting it.
3. Restore Defender for Cloud paid-plan settings to their approved previous state.
4. Delete or archive participant GitHub repositories if they were centrally created.
5. Unassign Copilot seats and downgrade the GitHub org plan if you upgraded it only for
   the workshop.
6. Delete any manually created Entra users that Terraform does not own.
7. Detach provider registrations from Terraform state, then destroy the base infrastructure:

```bash
cd baseInfra/terraform
terraform state rm 'module.resource_providers[0]'
terraform plan -destroy -var-file local.tfvars -out destroyplan
terraform show destroyplan
terraform apply destroyplan
```

Verify the subscription is empty enough for your governance rules:

```bash
az resource list --subscription "$SUBSCRIPTION_ID" -o table
az consumption budget list --subscription "$SUBSCRIPTION_ID" -o table
```

Delete the Terraform state resource group last, after you no longer need state for cleanup.
Repeat cost checks for several days because billing data lags.
