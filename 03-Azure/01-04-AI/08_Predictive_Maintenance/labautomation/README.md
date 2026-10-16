# Lab automation

This folder is optional. Delete it if this MicroHack does not need automated Azure provisioning.

When present, the MicroHack platform reads [lab-defaults.json](lab-defaults.json) to determine how to scope lab environments. It invokes [deploy-lab.ps1](deploy-lab.ps1) once per participant and [shared-deploy-lab.ps1](shared-deploy-lab.ps1) once per subscription before participant deployments begin.

## Folder layout

```text
labautomation/
|-- data/                   # Canonical seed JSON and kb-wiki markdown; included in the lab package
|-- lab-defaults.json        # Platform-facing configuration
|-- deploy-lab.ps1           # Per-participant deployment hook + data seeding
|-- shared-deploy-lab.ps1    # Resource-provider registration (once per subscription)
|-- main.bicep               # Predictive Maintenance infrastructure
`-- get-keys.sh              # Participant-run script: resolves resource names/keys into a repo-root .env
```

The generated `.env` uses `AZURE_AI_PROJECT_ENDPOINT` for the Foundry project endpoint
across the agents and workflow.

## What `main.bicep` provisions

- Storage account with a `machine-wiki` blob container (knowledge base articles).
- Cosmos DB account (serverless) with the `FactoryOpsDB` database and its 10 containers
  (partition keys and the 30-day TTL on `Telemetry` match the source hack's seeding script).
- Azure AI Search, Microsoft Foundry account/project with the `gpt-5.4-mini`, `gpt-5.4`, and
  `text-embedding-3-large` model deployments, and the AI Search/App Insights connections.
- API Management (`Machine API` and `Maintenance API`), including the inline XML policies that
  query Cosmos DB directly via APIM's managed identity — fully declarative, no post-deployment
  script needed for these two APIs.
- Container Registry and a Container Apps managed environment, for participants who choose the
  optional stretch goal in Challenge 5 (deploying the Aspire app as a container). No container app
  is pre-created; participants build and deploy their own image.
- Role assignments granting the participant (`userObjectId`) the data-plane access they need
  (Cosmos DB Data Contributor, Storage Blob Data Contributor, Foundry "Azure AI User") in addition
  to the subscription/resource-group Owner access the Hackbox platform already grants.

## Data seeding

Cosmos DB documents and the knowledge-base markdown files are **not** part of `main.bicep` — they
are actual data content, not infrastructure, so they can't be expressed declaratively. Instead,
`deploy-lab.ps1` seeds them automatically right after the Bicep deployment succeeds, using only
PowerShell and the `az` CLI (no bash, no Python):

- Cosmos DB documents: read from [data/](./data/) inside this folder and inserted via signed Cosmos DB
  REST calls (HMAC-SHA256 over the account's primary key — the same authentication scheme the
  Cosmos SDKs use internally, reimplemented here in plain PowerShell).
- Knowledge base articles: uploaded from [data/kb-wiki/](./data/kb-wiki/) to the `machine-wiki` blob container
  via `az storage blob upload-batch`.

Blob uploads disable CLI progress reporting because its stderr output is otherwise interpreted
as child-job errors by Hack Console. Actual errors remain visible and nonzero exit codes fail the script.

Upload the entire contents of `labautomation/`, including its `data/` subfolder, to Hack Console.
These are the only copies of the seed assets; no sibling folder or runtime download is required.
The deployment script checks that all required JSON files and the wiki folder are present before
provisioning. Missing assets, document upsert failures, and blob upload failures terminate the script
instead of reporting a successfully seeded lab.

This means participants never need to run a manual seeding step — by the time they receive their
Hackbox credentials, the data is already loaded. `walkthrough/challenge-01/solution-01.md`
documents a manual fallback re-seed command in case this automatic step needs to be repeated.

## Authoring guidance

- Keep each participant deployment isolated.
- Put shared resources and one-time subscription preparation in `shared-deploy-lab.ps1`.
- Use `Get-MhhStableHash` when deterministic per-participant resource names are required.
- Return participant-facing values as `HackboxCredential` hashtables.
- Never return participant-specific secrets from the shared deployment hook.

For the complete platform contract and helper cmdlet reference, see the [upstream MicroHack template documentation](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md).
