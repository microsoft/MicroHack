# Challenge 1 solution: Monitor the portals and build the regulatory lake

**[Home](../../README.md)** - [Challenge](../../challenges/challenge-01.md) - [Next Solution →](../challenge-02/solution-02.md)

**Duration:** 60 minutes

## Expected monitor output (Monday)

```text
Regulatory Web and Change Monitor - monday (2027-01-11), run 1
  Pages crawled:          15 (5 index pages)
  Links not followed:     2 (outside the allowlisted portals)
  New documents:          9  EU-SA-2027-004 v1, EU-GD-2027-011 v1, EU-GD-2027-019 v1, UK-SA-2027-002 v1, UK-REG-2027-001 v1, US-EL-2027-007 v1, US-REG-2027-003 v1, US-CD-2027-015 v1, UK-PR-2027-001 v1
  Updated documents:      0
  Duplicates ignored:     1
    - EU-SA-2027-004 v1 (same content at another address): portal://eu-medicines-regulator/news/2027-01-11-caldivex.html
  Change events written:  9  (lake-raw/events)
  Change log:             regulatory-knowledge/change-log.md
  Summary saved:          lake-raw/reports/monitor-monday-run1.txt
Uploaded the lake to storage account '<StorageAccountName>': containers 'lake-raw' and 'regulatory-knowledge'.
```

The repeat run in step 6 is `run 2`, with `New documents: 0`, `Duplicates ignored: 10`, `Change events written: 0` and the line `Nothing changed since the last crawl, so no new change events were raised.` If a participant's **first** run already shows 0 new, someone has crawled Monday before in this lab; the change log under *Monitor runs* shows every run.

### Answers to the Part B questions

- **15 pages**, of which **5** are portal home pages: they contain links, not documents.
- `EU-SA-2027-004` appears on the **safety** page and on a **news** mirror. The news page has a different menu, footer and spacing, but after normalisation the text and therefore the fingerprint are identical, so it is one document with two addresses.
- Two links point outside the portals (`https://example.org/...`). A crawler that follows them could wander anywhere. An **allowlist** keeps the crawl predictable, polite and auditable.

## The ten publications

| ID | Type | Region | Applies to Caldova? | Why it is in the lab |
|---|---|---|---|---|
| EU-SA-2027-004 | Safety alert | EU | Yes: both products | The headline change: label, DHPC and risk management plan |
| EU-GD-2027-011 | Guidance | EU | Yes: trial CAL-301 | Clinical domain, hidden in a study register |
| EU-GD-2027-019 | Guidance | EU | **No** | Veterinary medicines; tests rejection of irrelevant items |
| UK-SA-2027-002 | Safety alert | UK | Yes: tablets only | The pen is not sold in the UK |
| UK-REG-2027-001 | Regulation | UK | Yes: procedure SOP-PV-003 | Names no product; applies to every UK authorisation holder |
| US-EL-2027-007 | Enforcement letter | US | Yes: pen via CMO-17 | Never names Caldivex; linked through quality records |
| US-REG-2027-003 | Regulation | US | Yes: tablets | Linked to the open CAPA-2026-031 and an existing task |
| US-CD-2027-015 | Coverage decision | US | Yes: tablets | Revised on Tuesday (v2) |
| UK-PR-2027-001 | Pricing rule | UK | Yes: tablets | Market access; the UK forecast uses the old rate |
| EU-SA-2027-004 mirror | (duplicate) | EU | n/a | Tests de-duplication |

Every publication type in the case overview appears once: regulation, guidance, safety alert, enforcement letter, coverage decision and pricing rule. All five domains are covered.

## Knowledge base setup notes

- The knowledge source must point at **`regulatory-knowledge`**. Indexing `lake-raw` would add raw HTML copies and JSON events, which makes retrieval noisy and duplicates citations.
- Two identities are involved, and both are set up by the template:
  - **Connect** uses **Project Managed Identity**: the project's identity has Search Service Contributor, Search Index Data Contributor and Search Index Data Reader on the search service. Search API keys are disabled, so *API Key* fails.
  - The **knowledge source** uses **System assigned identity**: the search service's identity has Storage Blob Data Reader on the storage account and Cognitive Services OpenAI User on the Foundry account (for embeddings). The storage account has no access keys, so *API Key* fails.
- The portal creates an indexer named **`caldova-lake-indexer`**. After Monday's crawl it processes **21 items, 0 failed**: 9 documents, the change log, 9 internal records, `reference/geographies.md` and `tracking/task-register.md`. Participants re-run this indexer after every monitor run or sign-off.
- **Minimal** reasoning effort with **extractive** output is deliberate: the knowledge base only retrieves, and the agents reason. This also keeps cost and latency low.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ERROR: Azure Storage command failed … AuthorizationPermissionMismatch` | Role assignment still propagating, or the wrong subscription | Wait 5 minutes; check `az account show`; use the exact `StorageAccountName` |
| `The request may be blocked by network rules of storage account` | Tenant automation disabled public network access on the new storage account (seen in managed tenants such as MCAPS). The template's `SecurityControl: Ignore` tag prevents it; accounts deployed before the tag existed need it added | Facilitator: `az storage account update -n <StorageAccountName> -g <ResourceGroupName> --tags SecurityControl=Ignore`, then the same command with `--public-network-access Enabled` |
| `python3: No module named regintel` | Not in the lab folder | `cd` to `…/11_Healthcare_Regulatory_Intelligence` |
| Cloud Shell session lost | Cloud Shell without storage is temporary | Repeat the clone. The tool downloads its state from `lake-raw` before each run, so nothing is lost |
| Search service not offered in Foundry | Connected to the wrong project | Open the project that matches `FoundryProjectEndpoint` |
| Indexing fails with a permission error | Managed identity not selected | Edit the knowledge source and choose the search service's system-assigned identity |
| Running the Monday crawl twice | Safe | The second run reports 0 new and only duplicates; no new events are written |
