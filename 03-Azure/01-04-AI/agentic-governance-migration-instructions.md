# Task: Migrate Citadel / Agentic Governance workshop into MicroHack lab format

You are helping migrate an existing Citadel AI Governance workshop into the Microsoft MicroHack repository structure.

## Objective

Create the **labautomation** foundation for a new Belgium MicroHack lab focused on **Agentic Governance**.

The goal is to recreate the same Azure resources that the original workshop provisions with `azd up`, but adapted to the MicroHack platform model:

- Deployment must be **resource-group scoped**, not subscription scoped.
- The MicroHack platform pre-creates the resource group.
- The platform invokes `labautomation/deploy-lab.ps1`.
- The script must follow the same contract and style as existing MicroHack labs.
- Workshop notebooks should be kept and reused as-is as challenges; do not modify notebook content unless explicitly asked later.

## Source workshop repository

Use this public repository as the source baseline:

- Workshop branch and folder:
  https://github.com/mohamedsaif/ai-hub-gateway-solution-accelerator/tree/workshop/workshop

- Full deployment guide reference:
  https://github.com/mohamedsaif/ai-hub-gateway-solution-accelerator/blob/main/guides/full-deployment-guide.md

Important: in the full deployment guide, use the **Existing Resource Group Deployment Execution** section as the reference for adapting deployment to RG scope.

If GitHub Copilot cannot reliably fetch or inspect these public links, stop and ask the user to provide a local clone or downloaded copy of the workshop repository.

## Local reference MicroHack modules

Use these local modules as implementation style references:

1. Inventory Planning Agentic:
   `/Users/alibekjakupov/Documents/current/ai-gov-hack/MicroHack/03-Azure/01-04-AI/03_Inventory_Planning_Agentic`

2. Agentic Contract Lifecycle Management:
   `/Users/alibekjakupov/Documents/current/ai-gov-hack/MicroHack/03-Azure/01-04-AI/04_Agentic_Contract_Lifecycle_Management`

Study especially:

- `challenges/`
- `labautomation/`
- `labautomation/deploy-lab.ps1`
- `labautomation/lab-defaults.json`
- any local helpers such as `run-local.ps1`, `deploy.ps1`, `deploy.sh`
- README conventions

## Required MicroHack conventions

Follow the existing MicroHack format exactly.

### Folder structure

The new lab should eventually follow this pattern:

```text
<new-agentic-governance-lab>/
  README.md
  challenges/
    challenge-01.md
    challenge-02.md
    ...
  labautomation/
    README.md
    deploy-lab.ps1
    lab-defaults.json
    run-local.ps1          # optional but recommended for local verification
    deploy.ps1             # optional local helper
    deploy.sh              # optional local helper
    infra/                 # only if needed; goal is PowerShell-first automation
  images/
  walkthrough/
  src/                     # only if needed by the lab
```

### Platform deployment script contract

`labautomation/deploy-lab.ps1` must keep this parameter block shape:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)
```

For `resourcegroup` and `resourcegroup-with-subscriptionowner`:

- Do not call `Connect-AzAccount`.
- Do not create the resource group.
- Assume the platform has already set the Azure context.
- Assume the resource group exists.
- Deploy all resources into `$ResourceGroupName`.

For `subscription` mode:

- Support only if consistent with existing reference labs.
- Prefer resource-group mode as the primary path.

### lab-defaults.json

Create a `labautomation/lab-defaults.json` similar to the reference labs:

```json
{
  "$schema": "https://raw.githubusercontent.com/microsoft/MicroHack/refs/heads/main/lab-defaults-schema.json",
  "groups": [],
  "deploymentType": "resourcegroup",
  "labsPerSubscription": 8,
  "preferredLocation": "swedencentral, westeurope, norwayeast",
  "estimatedDailyCostsUsd": 5.0
}
```

Adjust cost and labs-per-subscription only if the Citadel resources require it.

## Workshop-specific requirements

The Norway workshop baseline is good. Preserve the notebooks.

The workshop currently includes these notebooks:

```text
1. llm-backend-onboarding-runner.ipynb
2. citadel-universal-llm-api-all-models-tests.ipynb
3. citadel-access-contracts-tests.ipynb
4. citadel-agent-frameworks-tests.ipynb
5. citadel-pii-processing-tests.ipynb
6. citadel-unified-ai-api-tests.ipynb
7. citadel-hosted-agent-with-agt.ipynb
8. publish-and-use-a2a-endpoint.ipynb
9. publish-and-use-hr-mcp-via-apim.ipynb
```

These notebooks should become the basis for the MicroHack `challenges/` material, but initially focus on **labautomation**.

Important: the user believes the notebooks are good and should not be modified for now.

## JWT / Entra ID requirement

Skip the JWT-specific parts.

The workshop troubleshooting says:

> For JWT tests: ensure Entra ID setup has been completed

For this MicroHack migration, ignore / skip JWT and Entra ID setup sections. Do not build lab automation that depends on attendee-specific Entra app registration for JWT testing unless explicitly requested later.

## Deployment goal

Recreate what the workshop's `azd up` deploys, but via MicroHack-compatible PowerShell automation.

The deployment should provision the Citadel Governance Hub equivalent resources, including resources such as:

- API Management
- Azure AI Foundry / Azure AI Services accounts and projects
- model deployments
- Cosmos DB
- Event Hub
- Key Vault
- Log Analytics
- Application Insights
- Logic App / workflow for usage ingestion if part of the original deployment
- managed identities
- RBAC assignments required for APIM, Logic App, Foundry, Key Vault, Cosmos, Event Hub
- networking resources if required by the workshop baseline

Also account for the sample Foundry spoke deployment that the workshop currently performs after `azd up` with:

```bash
./workshop/scripts/deploy-spoke-foundry.sh --spoke-suffix 1
```

or PowerShell equivalent:

```powershell
.\workshop\scripts\deploy-spoke-foundry.ps1 -SpokeSuffix 1
```

Determine whether the MicroHack labautomation should deploy the spoke in the same platform run or expose it as a separate helper. Prefer a smooth attendee experience: resources needed for notebooks should already exist after platform provisioning where possible.

## Existing workshop structure to inspect

From the workshop source, inspect:

```text
azure.yaml
bicep/
bicep/infra/
workshop/readme.md
workshop/scripts/
workshop/scripts/deploy-spoke-foundry.ps1
workshop/scripts/deploy-spoke-foundry.sh
workshop/scripts/cleanup-apim-defaults.ps1
workshop/scripts/import-model-pricing.py
workshop/scripts/model-pricing.json
workshop/requirements.txt
workshop/pyproject.toml
workshop/governed-agent/
workshop/hosted-agent/
workshop/mcp-hr/
```

The key task is to understand the Bicep/azd deployment graph and reproduce it in PowerShell or wrap RG-scoped deployment correctly.

## Methodological plan

Proceed in phases. Do not jump directly into editing.

### Phase 1 - Inspect references

1. Read the two local reference labs' `labautomation` folders.
2. Identify the exact MicroHack platform conventions:
   - parameter contract
   - output format
   - `HackboxCredential` objects
   - region fallback pattern
   - RBAC pattern
   - local `run-local.ps1` pattern
   - error handling style
3. Read the workshop deployment guide, especially Existing Resource Group Deployment Execution.
4. Read the workshop Bicep/azd entry points and deployment scripts.
5. Produce a short internal map of:
   - resources deployed by `azd up`
   - outputs needed by notebooks
   - resources deployed by the spoke script
   - environment variables consumed by notebooks

### Phase 2 - Decide deployment approach

Choose the safest implementation strategy:

Preferred options, in order:

1. **Resource-group scoped PowerShell orchestration using Az modules / ARM REST**, following the Inventory lab style.
2. **PowerShell wrapper around resource-group-scoped Bicep**, if converting all Bicep manually would be risky.
3. Avoid subscription-scope deployment unless absolutely necessary.

The user asked that the Bicep script be transformed to PowerShell scripts and placed in `labautomation`. That means the final attendee/platform entry point must be `deploy-lab.ps1`, even if some implementation still invokes RG-scoped templates internally.

Be explicit if full Bicep-to-PowerShell conversion is too risky in one step; prefer a reliable phased migration.

### Phase 3 - Create labautomation

Create:

```text
labautomation/
  README.md
  deploy-lab.ps1
  lab-defaults.json
  run-local.ps1
```

Optional:

```text
labautomation/deploy.ps1
labautomation/deploy.sh
labautomation/infra/
```

Only create `infra/` if necessary.

`deploy-lab.ps1` should:

1. Accept the MicroHack platform parameters.
2. Resolve candidate regions from `$PreferredLocation`, falling back to:
   - `swedencentral`
   - `westeurope`
   - `norwayeast`
3. Use `$ResourceGroupName` for resourcegroup mode.
4. Generate deterministic DNS-safe suffixes using `Get-MhhStableHash`.
5. Deploy resources idempotently.
6. Assign required RBAC to every user in `$AllowedEntraUserIds`.
7. Avoid secrets where possible.
8. Output clear `[INFO]`, `[OK]`, `[WARN]` messages.
9. Return dashboard values using `@{ HackboxCredential = ... }`.

### Phase 4 - Dashboard outputs

Return all values attendees need to run the unchanged notebooks.

Likely outputs include, depending on what the notebooks require:

- ResourceGroupName
- APIM gateway endpoint
- APIM name
- APIM subscription key or instructions to retrieve it safely
- Foundry project endpoint
- Foundry account/project names
- model deployment names
- Cosmos DB endpoint/name
- Event Hub namespace/name
- Key Vault name
- Application Insights connection string
- Log Analytics workspace name
- spoke resource group name
- spoke Foundry project endpoint

Inspect the notebooks before finalizing this list. Do not guess.

### Phase 5 - Respect no-JWT scope

Search for JWT-related setup, tests, variables, or app registration requirements.

Do not automate JWT/Entra app setup unless absolutely required for non-JWT parts.

If notebooks contain JWT cells, later challenge instructions should tell attendees to skip those cells/sections.

### Phase 6 - Validate

Validation should include:

1. Static review of PowerShell syntax.
2. Local dry-run support through `run-local.ps1`.
3. Confirm script can run in `resourcegroup` mode.
4. Confirm it does not require subscription-level deployment scope except for role assignments the platform grants.
5. Confirm all `HackboxCredential` outputs are emitted.
6. Confirm all notebook-required values can be discovered from Azure or emitted to dashboard.

Do not claim success without verification.

## Coding style requirements

Follow the style of the reference labs:

- PowerShell 7 compatible.
- `$ErrorActionPreference = "Stop"`.
- Use helper functions for ARM REST calls if using `Invoke-AzRestMethod`.
- Throw on non-2xx control plane responses.
- Use idempotent create-or-update patterns.
- Use full `https://management.azure.com/...?...api-version=...` URIs if REST is used.
- Avoid broad silent catches.
- Use `[INFO]`, `[OK]`, `[WARN]` output prefixes.
- Never emit secrets in logs unless they are intended dashboard credentials.
- Use `HackboxCredential` output objects for attendee dashboard values.
- Keep platform parameter contract unchanged.

## Important project context

This is for a Belgium MicroHack on **Agentic Governance**.

The user is adapting previous Norway workshop materials.

Meeting context:

- Deployment must be automated.
- Scope must be resource group, not subscription.
- The full deployment guide's Existing Resource Group Deployment Execution is the reference.
- The workshop notebooks are good and should be reused.
- The initial implementation focus is `labautomation`.

## Ask before proceeding if blocked

If any of these are true, stop and ask the user:

- You cannot access the workshop repository contents from GitHub.
- You cannot inspect the local reference labs.
- You cannot identify which Bicep files/resources `azd up` deploys.
- You need the user to provide a local clone of the workshop repo.
- You are unsure where the new Agentic Governance module should be created.
