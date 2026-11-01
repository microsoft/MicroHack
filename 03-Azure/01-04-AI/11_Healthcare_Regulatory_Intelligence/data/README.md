# The data in this lab

[Home](../README.md)

Everything here is fictional and safe to share: no patients, real companies or real regulators. The data has three parts, matching the case overview's *data to integrate*.

## 1. Authority and payer publications (`portals/`)

Five training websites stored as HTML, as the monitor would see them on two days:

| Portal | Region | Kind | Publications |
|---|---|---|---|
| `eu-medicines-regulator` | EU | Health authority | Safety alert, trial-results guidance, veterinary guidance (irrelevant), a news mirror (duplicate) |
| `uk-medicines-regulator` | UK | Health authority | Safety alert, pharmacovigilance regulation |
| `us-medicines-regulator` | US | Health authority | Warning letter to contract manufacturer CMO-17, nitrosamine regulation |
| `us-health-plan` | US | Payer | Coverage decision (revised on Tuesday) |
| `uk-pricing-scheme` | UK | Payer / pricing scheme | 2027 payment rate |

`portals/tuesday/` stores only the pages that changed since Monday; the monitor serves Monday's copy for everything else, like a real website where most pages stay the same.

## 2. Caldova's internal records (`internal/`)

| File | What it holds | Example IDs |
|---|---|---|
| `products.md` | Products, markets, manufacturing sites, marketing authorisations | CDX-TAB, CDX-PEN, CMO-17 |
| `labels.md` | Current label versions and what sections 4.4 and 4.8 say today | LBL-EU-TAB, LBL-UK-TAB |
| `studies.md` | Clinical studies and their disclosure status | CAL-301, CAL-401 |
| `submissions.md` | Past and planned regulatory submissions | SUB-2026-031, SUB-2027-002 |
| `sops.md` | Standard operating procedures and what they say today | SOP-LAB-001, SOP-PV-003 |
| `quality-records.md` | CAPAs, deviations and contract manufacturers | CAPA-2026-031, DEV-2026-114 |
| `market-access.md` | Payer dossiers, formulary position and pricing forecasts | MA-US-DOSSIER, MA-UK-FORECAST |
| `owners.md` | Owner role per domain, who approves, and how internal due dates are set | n/a |
| `history.md` | Earlier changes and the decisions taken | n/a |

`tracking/tasks.json` seeds the task register with three existing tasks; one of them is already overdue.

## 3. Reference data (`reference/`)

| File | Used for |
|---|---|
| `sources.json` | The monitor's **allowlist**: which portals to crawl, their region, publisher and kind |
| `portfolio.json` | Product names the monitor looks for when tagging documents |
| `domains.json` | Keyword rules that tag documents with clinical, labelling, manufacturing, vigilance or market access |
| `geographies.md` | Regions, publishers, Caldova entities and the publication types, including the date the story starts |

## What the monitor produces: the regulatory lake

Running `python3 -m regintel monitor` writes to `out/lake/` locally, and to Azure Blob Storage when you pass `--account`:

| Container | Folder or file | Written by | Indexed by Foundry IQ |
|---|---|---|---|
| `lake-raw` | `raw/<day>/<portal>/…` | Monitor (pages exactly as crawled) | No |
| `lake-raw` | `events/EVT-<doc>-v<n>.json` | Monitor (one change event per new or updated version) | No |
| `lake-raw` | `state/monitor-state.json` | Monitor (fingerprints and versions) | No |
| `lake-raw` | `tracking/tasks.json`, `tracking/audit-log.jsonl` | Sign-off tool (the source of truth) | No |
| `regulatory-knowledge` | `documents/<doc>-v<n>.md` | Monitor (normalised text, metadata, paragraph labels) | Yes |
| `regulatory-knowledge` | `change-log.md` | Monitor | Yes |
| `regulatory-knowledge` | `internal/`, `reference/` | Monitor (copied from this folder) | Yes |
| `regulatory-knowledge` | `tracking/task-register.md` | Sign-off tool (readable register and audit trail) | Yes |
| `regulatory-knowledge` | `briefings/EVT-….md` | Event-driven assistant (Challenge 6) | Yes |

## Tool reference

Run from the lab folder. Python 3.9 or later; no packages to install.

| Command | What it does |
|---|---|
| `python3 -m regintel [--account NAME] monitor --day monday\|tuesday` | Crawl, detect changes, load the lake |
| `python3 -m regintel [--account NAME] signoff FILE.json` | Validate a human decision and create tasks |
| `python3 -m regintel [--account NAME] task TASK-ID --status open\|"in progress"\|blocked\|done --by ROLE [--note TEXT]` | Record progress |
| `python3 -m regintel status` | Summarise the local lake |

Without `--account`, everything stays in `out/lake/` on the machine you are using. With `--account`, the tool first downloads the shared state and task register, then uploads the result, using your Azure CLI sign-in. No keys are used.
