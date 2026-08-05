# Deploy the CLM MCP server to Azure Container Apps

Challenge 4 · Part A. This hosts `src/mcp_server/server.py` as a **remote** MCP
server (streamable HTTP) so a Foundry agent can call your CLM tools over the
network — no local process required.

## What gets deployed

- A single **Azure Container App** named `clm-mcp` (external HTTPS ingress on
  port `8000`) built from the repo‑root [`Dockerfile`](../../Dockerfile).
- The app runs `python src/mcp_server/server.py --http`, exposing the MCP
  endpoint at `https://<app>.<region>.azurecontainerapps.io/mcp`.
- A **system‑assigned managed identity** granted a data‑plane role on your
  Foundry account, so the server's own tools (`draft_contract`,
  `analyze_contract`) can call your models via `DefaultAzureCredential`.

## Run it (from the repo root)

```bash
RESOURCE_GROUP=<your-lab-rg> \
AZURE_AI_PROJECT_ENDPOINT=<your-project-endpoint> \
FOUNDRY_ACCOUNT_ID=<your-foundry-account-resource-id> \
  bash deploy/mcp-server/deploy.sh
```

Find your Foundry account resource id with:

```bash
az cognitiveservices account list -g "<your-lab-rg>" --query "[].id" -o tsv
```

The script prints the `…/mcp` URL at the end. Use it in the Foundry portal
(Task 4 · Part B) or locally with `CLM_MCP_URL=<url> python src/orchestrator_mcp.py`
(Task 4 · Part C).

> **Windows / no bash?** Run the same `az containerapp up …` / `az containerapp
> identity assign …` / `az role assignment create …` commands from the script by
> hand in PowerShell — they are plain `az` calls.

## Security note

The endpoint is deployed with **external ingress and no auth** for hack
simplicity — anyone with the URL can call the tools. For anything real, put it
behind auth (a key header, APIM, or a **private** endpoint on a dedicated MCP
subnet) as described in the challenge's *Go Further* section.
