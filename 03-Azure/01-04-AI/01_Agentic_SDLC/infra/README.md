# `infra/` — Challenge 4 starter scaffold (optional)

> **Optional starting point, not a required or "correct" answer.** This is a
> deliberately incomplete **skeleton** for [Challenge 4 — Deploy into Azure](../challenges/challenge-04.md).
> It removes blank-page boilerplate (structure, parameters, module wiring, OIDC
> plumbing) so your 60 minutes go into the interesting agentic work — authoring
> and refining the deploy with Copilot, deploying, and debugging — **not**
> scaffolding. The meaningful engineering decisions are left as clearly-marked
> `// TODO`s on purpose. Extend it, replace it, or ignore it.

## Intended topology

Azure **Container Apps** as the compute target:

```
        Azure Container Registry (ACR)
                 │  (holds api + frontend images)
                 ▼
   ┌──────────── Container Apps Environment ────────────┐
   │                                                    │
   │   frontend (nginx)            api (Node/Express)   │
   │   external ingress :80  ────► ingress :3000        │
   │   proxies /api via nginx      (internal OR external)│
   │                                                    │
   └────────────────────┬───────────────────────────────┘
                        │ logs
                        ▼
             Log Analytics workspace
```

- **ACR** — stores the two images the apps pull.
- **Log Analytics workspace** — a hard dependency of the Container Apps
  environment; provisioned first.
- **Container Apps Environment** — the shared boundary both apps run in. Apps in
  the same environment can address each other by app name (service discovery).
- **`api` Container App** — target port **3000** (matches `src/api-ts/Dockerfile`,
  which `EXPOSE`s 3000 and runs `npm start`).
- **`frontend` Container App** — external ingress on port **80** (matches
  `src/frontend/Dockerfile`, nginx). It is configured with `API_HOST` /
  `API_PORT` env vars pointing at the `api` app so nginx can reverse-proxy `/api`
  (see `src/frontend/nginx.conf` + `src/frontend/entrypoint.sh`).

## How the Bicep maps to the two Dockerfiles

| Dockerfile | Port | Container App | Notes |
| --- | --- | --- | --- |
| `src/api-ts/Dockerfile` | `EXPOSE 3000` | `<prefix>-<env>-api` | `targetPort: 3000`. Ingress internal-vs-external is a **TODO** decision. |
| `src/frontend/Dockerfile` | `EXPOSE 80` | `<prefix>-<env>-frontend` | `targetPort: 80`, external. Gets `API_HOST` = the api app name and `API_PORT` = `3000`. The entrypoint also honours `API_PROTOCOL` (default `https`). |

The workflow builds each image from its own context (`src/api-ts` and
`src/frontend`) and pushes to ACR; the Bicep then references those image tags.

## Files

| File | Purpose |
| --- | --- |
| `main.bicep` | `targetScope = 'resourceGroup'`. Wires ACR, Log Analytics, the environment, and the two apps by calling the modules. Declares parameters + outputs. |
| `modules/registry.bicep` | ACR (stub — SKU/admin/network are TODO). |
| `modules/loganalytics.bicep` | Log Analytics workspace (stub — retention/SKU TODO). |
| `modules/containerapp-env.bicep` | Container Apps managed environment. |
| `modules/containerapp.bicep` | Generic app module, reused for **both** api and frontend. |
| `main.parameters.json` | Placeholder parameter values with TODO comments. |

## What's provided vs. deliberately left as `TODO`

**Provided (so you don't start from a blank page):**

- Module structure and the wiring between them.
- Sensible parameters (`location`, `namePrefix`, `environmentName`, image
  references, `minReplicas` / `maxReplicas`) and outputs (ACR login server,
  frontend URL, api FQDN).
- The port mapping (api `3000`, frontend `80`) and the `API_HOST` / `API_PORT`
  proxy wiring between frontend and api.
- OIDC-based CI/CD plumbing in the workflow (no long-lived secrets).

**Left as `TODO` (the decisions that make this a real deploy — do these):**

- **SKUs** — ACR tier, Log Analytics retention, container CPU/memory.
- **api ingress visibility** — public (its own URL, easy debugging) vs.
  internal-only (reached solely by the frontend inside the environment).
- **Database / storage strategy** — the api ships with an in-container
  **SQLite** DB. In Container Apps that is **ephemeral** (it resets on every
  revision/scale event). Choose one: keep it ephemeral for a demo, mount an
  **Azure Files** volume to persist it, or move to a **managed DB**
  (Azure SQL / PostgreSQL) and inject a connection string. *Not decided for you.*
- **Registry auth** — the scaffold defaults to ACR **admin credentials** for a
  fast first deploy; the preferred approach is a **user-assigned managed
  identity** with the `AcrPull` role (no secrets). Swap it in.
- **Env vars / secrets** — real app configuration and how it's referenced.
- **Scaling rules** — replica counts are set, but add real scale triggers
  (HTTP concurrency, CPU, ...).
- **Service discovery** — confirm the frontend→api wiring works with whichever
  ingress visibility you pick.

## Deploy it manually

```bash
# 1. Sanity-check the template compiles
az bicep build --file infra/main.bicep        # or: bicep build infra/main.bicep

# 2. Create a resource group
az group create --name <rg-name> --location <region>

# 3. Deploy (fill in the image references — see main.parameters.json TODOs)
az deployment group create \
  --resource-group <rg-name> \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --parameters \
      apiImage="<acr>.azurecr.io/api:<tag>" \
      frontendImage="<acr>.azurecr.io/frontend:<tag>"

# 4. Read the outputs (e.g. the public frontend URL)
az deployment group show -g <rg-name> -n main \
  --query properties.outputs.frontendUrl.value -o tsv
```

> **Chicken-and-egg note:** the images live in the ACR this template creates, so
> on a first run either point `apiImage` / `frontendImage` at a temporary public
> placeholder image, deploy once to create the ACR, then build/push and redeploy
> — **or** split provisioning: create the ACR first, push images, then deploy the
> apps. The workflow leaves this ordering as a TODO for you to decide.

## Deploy it via the workflow

[`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) is an
OIDC-wired scaffold with `# TODO` steps (checkout → `azure/login` → build/push →
`az group create` → `az deployment group create` → update apps). It is **inert
by default**: the `push` trigger is commented out and it needs the OIDC secrets
below. Set those up, finish the TODO steps with Copilot, then run it from the
**Actions** tab (`workflow_dispatch`).

Required GitHub **secrets**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`. Required **variables**: `AZURE_RESOURCE_GROUP`,
`AZURE_LOCATION`. See the header comment in the workflow for the federated-
credential subject (`repo:<owner>/<repo>:ref:refs/heads/main`). No client secret
is stored — auth is OIDC only. **Setting up the OIDC federated credential is the
single most common stumbling block — do it first and verify with a trivial login.**

## Tooling note

The repo's `.vscode/mcp.json` preconfigures an **Azure MCP Server**
(`@azure/mcp`). You can use it during the challenge to explore/verify Azure
resources — it's handy but not required by this scaffold.
