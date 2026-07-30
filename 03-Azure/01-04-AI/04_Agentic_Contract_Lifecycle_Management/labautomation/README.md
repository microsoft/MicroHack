# labautomation — provisioning & seeding

Everything a coach or `azd` runs to stand up a team's environment lives here: the
**platform entry point** (`deploy-lab.ps1`), the **Bicep infrastructure**, and the
**local deploy scripts** that autofill `.env`. The **seed / setup / smoke-test**
helpers now live in [`../src/scripts/`](../src/scripts/) (they are run by
participants/coaches during the hack, never by the platform).

## Platform entry point (EMEA MicroHack)

The [microsoft/MicroHack](https://github.com/microsoft/MicroHack) platform provisions each
team's environment by invoking **`deploy-lab.ps1`** with a fixed parameter contract and reading
**`lab-defaults.json`** for its configuration:

| File | Role |
|------|------|
| [`deploy-lab.ps1`](deploy-lab.ps1) | **Platform entry point.** Deploys [`infra/resources.bicep`](infra/) into the platform-provided resource group and returns the Foundry / Search endpoints (and model names) to the user dashboard. Do **not** rename or change its parameter block — the platform silently skips scripts that don't match. |
| [`lab-defaults.json`](lab-defaults.json) | Platform config (`$schema`-validated): deployment type, region priority, per-user daily cost estimate. |

`deploy-lab.ps1` is the **platform** path; `deploy.sh` / `deploy.ps1` below remain the
**local / Codespaces** path (they autofill `.env` via `az` after `az login`). Both provision the
same resources from `infra/`.

**What `deploy-lab.ps1` does beyond a single deployment:**

- **Region fallback** — retries the deployment across `PreferredLocation` (then
  `swedencentral → westeurope → norwayeast`) until a region succeeds.
- **Claude quota preflight** — before each region attempt it probes Anthropic
  `GlobalStandard` quota for `claude-opus-4-8` and sets `deployClaudeModel=false`
  automatically when the region has no model/quota, so a Claude-less subscription still
  gets GPT + full infra instead of failing the whole deploy (the drafting agent falls
  back to the `gpt-5.4` orchestrator; Clause & Risk stays on `gpt-5.6-sol`). Force the decision with `DEPLOY_CLAUDE_MODEL=true|false`.
- **Multi-user RBAC** — grants the data-plane roles (Azure AI Developer, Cognitive
  Services User, Search Index Data Contributor, Search Service Contributor) to **every**
  id in `AllowedEntraUserIds`, so team labs work for all members (idempotent).
- **Bicep or ARM** — deploys `infra/resources.bicep` by default; pass **`-UseArm`** to
  deploy the equivalent `infra/azuredeploy.json` instead. That template is
  subscription-scoped (creates its own resource group), so `-UseArm` applies to
  `subscription` mode / manual runs; in `resourcegroup` modes it falls back to Bicep to
  respect the pre-created RG.
- **Console output** — emits `[INFO]/[OK]/[WARN]` progress and a summary block, plus a
  `HackboxCredential` record per endpoint / model name for the attendee dashboard.

## What gets provisioned

[`infra/`](infra/) holds the Bicep templates (plus `azuredeploy.json` for the
one-click **Deploy to Azure** button) that create the Microsoft Foundry project, the
GPT + Claude model deployments, Azure AI Search, Azure SQL, and Application Insights.
`azure.yaml` at the repo root points `azd` at this folder.

## Scripts

Provisioning scripts in **this folder** (local / Codespaces path):

| Path | Role |
|------|------|
| [`deploy.sh`](deploy.sh) · [`deploy.ps1`](deploy.ps1) | Provision resources and autofill the repo-root `.env` |

Seeding, setup & gate scripts — run by participants/coaches during the hack — live in
[`../src/scripts/`](../src/scripts/):

| Path | Role |
|------|------|
| [`write_env.py`](../src/scripts/write_env.py) | Writes `.env` from deployment outputs (also the `azd` postprovision hook) |
| [`setup_sharepoint_corpus.py`](../src/scripts/setup_sharepoint_corpus.py) | **Default corpus path** — one command that provisions the whole SharePoint grounding source in your own admin tenant (Entra app + admin consent + SharePoint site + PDF upload + index) |
| [`seed_corpus.py`](../src/scripts/seed_corpus.py) | Seeds the `clm-corpus` Azure AI Search index (SharePoint crawl or local-PDF fallback over `src/data/`) |
| [`seed_sql.py`](../src/scripts/seed_sql.py) | Optional — seeds the contract-status table in Azure SQL |
| [`setup_sharepoint_app.sh`](../src/scripts/setup_sharepoint_app.sh) · [`.ps1`](../src/scripts/setup_sharepoint_app.ps1) | Lower-level helper — just the Entra app registration (superseded by `setup_sharepoint_corpus.py`) |
| [`upload_corpus_to_sharepoint.py`](../src/scripts/upload_corpus_to_sharepoint.py) | Lower-level helper — upload the corpus PDFs into an existing SharePoint library |
| [`smoke_test.py`](../src/scripts/smoke_test.py) | Gate — confirms a tiny agent runs on **both** the GPT and Claude deployments |

## Getting started

```bash
az login
./labautomation/deploy.sh          # or: azd up   (Windows: labautomation\deploy.ps1)
# Default corpus path (own admin tenant): SharePoint app + consent + site + upload + index
python src/scripts/setup_sharepoint_corpus.py
# — or the no-SharePoint fallback: python src/scripts/seed_corpus.py
python src/scripts/smoke_test.py   # expect ✅ PASS before starting Challenge 2
```

> Pick **one** provisioning path (`azd up` **or** the deploy script **or** the
> one-click button) — don't mix them. The first two autofill your `.env`. See the
> **[Coach & Facilitator Guide](../docs/coach-guide.md)** for the full run-of-show and
> a reset/recovery playbook.

## Optional toggles & overrides

Set these before provisioning (`azd env set NAME value` for `azd up`, or export the env var
for `deploy.sh` / `$env:NAME` for `deploy.ps1`):

| Env var | Default | Purpose |
|---------|---------|---------|
| `DEPLOY_CLAUDE_MODEL` (`DEPLOY_CLAUDE` for the scripts) | `true` (auto on the platform) | Set `false` to skip the Anthropic Claude deployment when the subscription isn't entitled — the drafting agent then falls back to the `gpt-5.4` orchestrator (Clause & Risk stays on `gpt-5.6-sol`). On the platform path (`deploy-lab.ps1`) this is **auto-detected per region** from Anthropic quota; set it explicitly only to force the decision. |
| `CLAUDE_ORGANIZATION_NAME` | `Contoso` | Legal-entity name for the **required** Anthropic Marketplace attestation (`modelProviderData`). The template sends this so `azd up` auto-accepts the offer — no portal click-through, no `InvalidModelProviderData`. Override to describe your org. |
| `CLAUDE_COUNTRY_CODE` | `US` | Two-letter country code for the attestation. |
| `CLAUDE_INDUSTRY` | `technology` | Industry for the attestation (lowercase: `technology`, `finance`, `healthcare`, `education`, `retail`, …). |
| `DEPLOY_SQL` | `false` | Provision the optional Azure SQL contract-status store (needs `SQL_ADMIN_PASSWORD`). |
| `DEPLOY_BING` | `false` | Provision the optional Grounding with Bing Search resource + connection. |
