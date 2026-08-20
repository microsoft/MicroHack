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
**local** path (they autofill `.env` via `az` after `az login`). Both provision the
same resources from `infra/`.

**What `deploy-lab.ps1` does beyond a single deployment:**

- **Region fallback** — retries the deployment across `PreferredLocation` (then
  `swedencentral → westeurope → norwayeast`) until a region succeeds.
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
three GPT model deployments (`gpt-5.4`, `gpt-5.6-sol`, `gpt-5.4-nano`), Azure AI Search, Azure SQL, and Application Insights.
`src/azure.yaml` points `azd` at this folder (`../labautomation/infra`); run `azd up` from `src/`.

## Scripts

Provisioning scripts in **this folder** (local path):

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
| [`smoke_test.py`](../src/scripts/smoke_test.py) | Gate — confirms a tiny agent runs on each distinct GPT deployment (drafting shares `gpt-5.4` with orchestration) |

## Getting started

```bash
az login
./labautomation/deploy.sh          # or: (cd src && azd up)   (Windows: labautomation\deploy.ps1)
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
| `DEPLOY_SQL` | `false` | Provision the optional Azure SQL contract-status store (needs `SQL_ADMIN_PASSWORD`). |
| `DEPLOY_BING` | `false` | Provision the optional Grounding with Bing Search resource + connection. |
