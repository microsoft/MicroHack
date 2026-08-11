# Deploy the Teams "capture reference" bot to Azure Container Apps

Challenge 5 · Task 6, **no local run / no dev tunnel.** This hosts
`src/capture_reference_bot.py` on a stable public HTTPS endpoint so you can point
your Azure Bot's **Messaging endpoint** at it — instead of running the bot on
`localhost:3978` and forwarding it with `devtunnel`.

You still message the bot **once** in Teams (this doesn't change the Teams step).
On that first message the bot saves the conversation reference and **replies with
the values in the chat**, so you can copy them into your local `.env`.

## What gets deployed

- A single **Azure Container App** named `clm-capture-bot` (external HTTPS ingress
  on port `3978`) built from the repo-root [`Dockerfile`](../../Dockerfile).
- The image is shared with the MCP server; `APP_ROLE=capture-bot` makes it run
  `python src/capture_reference_bot.py` and bind `0.0.0.0` (`CAPTURE_BOT_HOST`) so
  the ingress can reach it. The bot exposes `…/api/messages`.
- **No managed identity / role** — this bot never calls Foundry models; it only
  authenticates to the Bot Framework with your own app's
  `MICROSOFT_APP_ID` / `MICROSOFT_APP_PASSWORD` / `MICROSOFT_APP_TENANT_ID`.

## Run it (from the repo root)

**Zero-config** — reads your repo-root `.env` for the three `MICROSOFT_APP_*`
values (from Task 6 step 1) and auto-discovers the resource group + region from
`AZURE_AI_PROJECT_ENDPOINT`, so the bot lands next to the rest of the lab:

```bash
bash deploy/capture-bot/deploy.sh          # Codespaces / Linux / macOS / Azure Cloud Shell
```
```powershell
./deploy/capture-bot/deploy.ps1            # Windows PowerShell ONLY — not for Codespaces/bash
```

Prereq: `az login` on your lab subscription. The script prints the
`…/api/messages` URL. Then:

1. Your Bot → **Configuration** → **Messaging endpoint** = that URL → **Apply**.
2. Your Bot → **Channels → Microsoft Teams → Open in Teams** → send `hi`.
3. Copy the `TEAMS_SERVICE_URL` + `TEAMS_CONVERSATION_ID` lines from the bot's
   reply into your local `.env` (or read them from
   `az containerapp logs show -n clm-capture-bot -g <rg> --tail 50`).
4. `python src/proactive_alerts.py --from-renewals --days 30`

### Overrides

An env var / parameter always wins over `.env` and discovery:

| What | `deploy.sh` (env var) | `deploy.ps1` (param) | Default |
|------|-----------------------|----------------------|---------|
| App name | `APP_NAME` | `-AppName` | `clm-capture-bot` |
| Resource group | `RESOURCE_GROUP` | `-ResourceGroup` | from Foundry account |
| Region | `LOCATION` | `-Location` | account region → `swedencentral` |
| Bot app id | `MICROSOFT_APP_ID` | `-AppId` | from `.env` |
| Bot app secret | `MICROSOFT_APP_PASSWORD` | `-AppPassword` | from `.env` |
| Bot app tenant | `MICROSOFT_APP_TENANT_ID` | `-AppTenant` | from `.env` |
| `.env` path | `ENV_FILE` | `-EnvFile` | `.env` |

## Clean up

This bot is throwaway. When you've captured the reference, delete it (and its
app registration + Azure Bot from Task 6):

```bash
az containerapp delete -n clm-capture-bot -g <rg> --yes
```

## Security note

The endpoint is deployed with **external ingress**, and the Bot Framework's own
token validation (scoped to your single tenant) is what protects `…/api/messages`.
The app secret is passed as a plain container env var for lab simplicity — fine
for a throwaway bot you delete afterwards; for anything real, move it to a
Container Apps **secret** and reference it with `secretref:`.
