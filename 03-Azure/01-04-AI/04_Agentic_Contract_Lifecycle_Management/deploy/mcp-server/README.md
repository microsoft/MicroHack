# Deploy the CLM MCP server to Azure Container Apps

Challenge 4 · Part A. This hosts `src/mcp_server/server.py` as a **remote** MCP
server (streamable HTTP) so a Foundry agent can call your CLM tools over the
network — no local process required.

## What gets deployed

- A single **Azure Container App** named `clm-mcp` (external HTTPS ingress on
  port `8000`) built from the src/ [`Dockerfile`](../../src/Dockerfile).
- The app runs `python src/mcp_server/server.py --http`, exposing the MCP
  endpoint at `https://<app>.<region>.azurecontainerapps.io/mcp`.
- A **system‑assigned managed identity** granted a data‑plane role on your
  Foundry account, so the server's own tools (`draft_contract`,
  `analyze_contract`) can call your models via `DefaultAzureCredential`.

## Run it (from the repo root)

**Zero-config** — the script reads your repo-root `.env` (the same file the agents
use) for `AZURE_AI_PROJECT_ENDPOINT` + `MODEL_*`, then **auto-discovers** the
resource group, Foundry account id and region from that endpoint. Usually just:

```bash
bash deploy/mcp-server/deploy.sh          # Codespaces / Linux / macOS / Azure Cloud Shell
```
```powershell
./deploy/mcp-server/deploy.ps1            # Windows PowerShell ONLY — not for Codespaces/bash
```

> **Codespaces / Cloud Shell = a Linux `bash` shell.** Use the `bash deploy/mcp-server/deploy.sh`
> line above — the `.ps1` is Windows PowerShell only and, run in bash, fails with
> `bash: ./deploy/mcp-server/deploy.ps1: Permission denied`.

Prereq: `az login` on your lab subscription. The script echoes what it discovered
(resource group / account / region), then prints the `…/mcp` URL. Use that URL in
the Foundry portal (Task 4 · Part B) or locally with
`CLM_MCP_URL=<url> python src/orchestrator_mcp.py` (Task 4 · Part C).

### Overrides

Auto-discovery guessing wrong (e.g. several AI accounts in the subscription)? Set
any value explicitly — an env var / parameter always wins over `.env` and discovery:

| What | `deploy.sh` (env var) | `deploy.ps1` (param) | Default |
|------|-----------------------|----------------------|---------|
| App name | `APP_NAME` | `-AppName` | `clm-mcp` |
| Resource group | `RESOURCE_GROUP` | `-ResourceGroup` | from Foundry account |
| Region | `LOCATION` | `-Location` | account region → `swedencentral` |
| Project endpoint | `AZURE_AI_PROJECT_ENDPOINT` | `-ProjectEndpoint` | from `.env` |
| Foundry account id | `FOUNDRY_ACCOUNT_ID` | `-FoundryAccountId` | discovered from endpoint |
| `.env` path | `ENV_FILE` | `-EnvFile` | `.env` |

```bash
# example: force a specific RG + account
RESOURCE_GROUP=rg-clm-lab \
FOUNDRY_ACCOUNT_ID=$(az cognitiveservices account list -g rg-clm-lab --query "[0].id" -o tsv) \
  bash deploy/mcp-server/deploy.sh
```

## Security note

The endpoint is deployed with **external ingress and no auth** for hack
simplicity — anyone with the URL can call the tools. For anything real, put it
behind auth (a key header, APIM, or a **private** endpoint on a dedicated MCP
subnet).
