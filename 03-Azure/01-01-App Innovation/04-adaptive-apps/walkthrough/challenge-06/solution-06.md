# Walkthrough Challenge 06 - Port the App Across Environments

[< Previous Solution](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-05/solution-05.md) - **[Home](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/Readme.md)** - [Next Solution](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/walkthrough/challenge-07/solution-07.md)

Duration: 45-75 minutes

## Coach notes

**Hosted prerequisites:** complete the workstation portion of Challenge 01 and
[Console setup](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-01-App%20Innovation/04-adaptive-apps/docs/console-setup.md).
Console supplies infrastructure only. Validate/explore 02 without reprovisioning,
then complete 03-05 to install Radius, create workspaces and abstractions (including
`artifacts/types.tgz`), and publish/register recipes before this application exercise.
Use the **Bash** examples and source `artifacts/console-env.sh` in each new
terminal. Keep its discovered names. All commands in this walkthrough use Bash.

### How we arrived here

1. **Challenge 02 prepared two Kubernetes targets.** `aks-adaptive-apps` is the
   Azure-managed AKS target. `k3s-azure-vm` is the private K3s target used for the Local
   platform and reached through the Azure Bastion API tunnel.
2. **Challenge 03 installed two independent Radius control planes.** The local workspace
   `ws-azure-prod` targets AKS and contains `env-azure-prod`; `ws-local-prod` targets K3s
   and contains `env-local-prod`. Each control plane has its own `rg-trading` group.
   Identical names do not imply shared state.
3. **Challenge 04 established contracts and the shared platform baseline.** The `core`
   capability portfolio installed identity, observability, and the applicable Istio
   strict-mTLS baseline on each cluster. The challenge then registered the portable
   `Radius.Resources/*` resource-type contracts separately in both Radius control planes
   and generated the local `artifacts/types.tgz` Bicep extension. A contract describes
   application-facing inputs and recipe-produced outputs; registering it does not create
   PostgreSQL, Event Grid, or application containers.
4. **Challenge 05 registered environment-specific recipes.** For the contracts exercised
   here, the selected environment now determines these implementations:

   | Portable contract | `env-azure-prod` on AKS/Azure | `env-local-prod` on K3s |
   | --- | --- | --- |
   | `Radius.Resources/postgreSqlDatabases` | Azure Database for PostgreSQL Flexible Server | In-cluster PostgreSQL |
   | `Radius.Resources/mqttBrokers` | Azure Event Grid MQTT | In-cluster Eclipse Mosquitto |
   | `Radius.Resources/workloadIdentities` | Azure/AKS workload identity mapping | Local Kubernetes mapping/no-op implementation |

   Challenge 05 also prepared Keycloak, AI, governance, and agent-guardrail recipe
   mappings for later challenges; the Challenge 06 core model does not exercise all of
   them.

   > [!IMPORTANT]
   > The manually authored Azure SQL recipe in Challenge 05 is a teaching example for
   > `Radius.Resources/sqlDatabases`. The Trading application in `iac/app.bicep` requests
   > `Radius.Resources/postgreSqlDatabases`, so Radius uses the PostgreSQL recipes shown
   > above rather than the custom Azure SQL recipe.

5. **Challenge 06 deploys the Trading application for the first time.** The same
   `iac/app.bicep` declares one `Applications.Core/applications` resource, the `backend`
   and `frontend` containers, and PostgreSQL, MQTT, and workload-identity capability
   requests in both environments. Radius resolves those requests through the recipes
   registered on the selected environment.

This handoff defines the portability boundary:

```text
Application team                         Platform team
------------------------------------     --------------------------------------
iac/app.bicep                            Radius control plane and environment
portable resource type contracts        recipe registrations
published image and safe parameters      Kubernetes and Azure implementations
```

The core deployment intentionally uses PostgreSQL, MQTT, and workload-identity
contracts. Local password authentication keeps the frontend usable. OIDC adaptation
belongs to Challenge 07, service communication to Challenge 08, and AI to Challenge 09.
Do not provision per-workload managed identities or AI services here.

Deployment parity is not runtime parity. On AKS, recipe execution creates Azure
Database for PostgreSQL Flexible Server; on K3s it creates an in-cluster PostgreSQL
workload. The `mqttBrokers` contract resolves to Azure Event Grid on AKS and Mosquitto
on K3s. The updated backend supports Event Grid's MQTT v5 enhanced authentication.
The portable contract is unchanged and the swap is a recipe decision, which is exactly
the seam Radius exists to provide. See
[Event Grid authentication and browser streaming](#event-grid-authentication-and-browser-streaming).

## Target discipline

Use these names without translation:

| Platform | Kubernetes context | Radius workspace | Environment | Group |
| --- | --- | --- | --- | --- |
| Private K3s | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

The K3s kubeconfig points to `https://127.0.0.1:16443`. That endpoint works only while
the Azure Bastion native-client tunnel is running. The tunnel exposes the Kubernetes
API on localhost; it does not expose application HTTP, HTTPS, MQTT, or SSH ports.

Each workspace targets an independent Radius control plane. Switching `kubectl`
context without switching the Radius workspace can deploy to the wrong platform.

## Stage 1: Inspect the application model

Open `iac/app.bicep`. The core model declares:

| Resource | Portable contract or Radius resource |
| --- | --- |
| Application | `Applications.Core/applications` |
| Database | `Radius.Resources/postgreSqlDatabases` |
| Broker | `Radius.Resources/mqttBrokers` |
| Workload identities | `Radius.Resources/workloadIdentities` |
| Workloads | `Applications.Core/containers` for `backend` and `frontend` |

The model does not name a PostgreSQL server, Event Grid namespace, Kubernetes
Deployment, Azure resource group, or VM address. Recipes own those choices.

The same published images are used on both targets:

```text
ghcr.io/microsoft/adaptive-apps/backend:latest
ghcr.io/microsoft/adaptive-apps/frontend:latest
```

### Generate the local Bicep extension when needed

Challenge 04 generated `artifacts/types.tgz`. The archive is intentionally ignored by
Git because it is generated for the installed Radius/Bicep toolchain.

**Bash:**

```bash
mkdir -p artifacts
if [[ ! -f artifacts/types.tgz ]]; then
  TYPES_FILE="$(mktemp)"
  curl --fail --location \
    "https://raw.githubusercontent.com/microsoft/adaptive-apps/885627980684e5bcc6fe4bbd2848c1ec247b0a0b/radius/resource-types/types.yaml" \
    --output "$TYPES_FILE"
  rad bicep publish-extension \
    --from-file "$TYPES_FILE" \
    --target artifacts/types.tgz \
    --force
  rm -f "$TYPES_FILE"
fi
```

`iac/bicepconfig.json` maps the `radiusResources` extension to this generated archive.
Do not commit `types.tgz`.

## Stage 2: Deploy to private K3s

### 1. Restore and select the K3s target

After every devcontainer restart, re-establish the tunnel before K3s commands.

**Bash:**

```bash
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-<subscription-id>}"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"

kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod

test "$(kubectl config current-context)" = "k3s-azure-vm"
test "$(rad workspace show --output json | jq -r '.connection.context')" = "k3s-azure-vm"
rad env show env-local-prod
```

### 2. Verify the Challenge 05 handoff

**Bash:**

```bash
rad resource-type list
rad recipe list \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod
```

Confirm default recipes exist for:

- `Radius.Resources/postgreSqlDatabases`
- `Radius.Resources/mqttBrokers`
- `Radius.Resources/workloadIdentities`

If one is missing, rerun the K3s portion of Challenge 05. Do not edit `iac/app.bicep`.

### 3. Deploy the model

Prompt for the local frontend password. The plaintext exists only long enough to pass
it across the CLI process boundary.

**Bash:**

```bash
read -rsp "Frontend password: " AUTH_PASSWORD
echo
rad deploy iac/app.bicep \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest \
  --parameters authUsername=admin \
  --parameters "authPassword=$AUTH_PASSWORD"
unset AUTH_PASSWORD
```

Do not save the password in a parameters file or command transcript.
The CLI argument is briefly visible to local process inspection, so run the lab only
on a trusted, single-user workstation or devcontainer host.

### 4. Validate graph, resources, and workloads

Radius stores the application Graph. resources and workload types. Let's check if we can retrieve these from the Radius control plane. 

**Bash:**

```bash
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

APP_NAMESPACE="$(bash resources/resolve-trading-namespace.sh ws-local-prod env-local-prod)" &&
  export APP_NAMESPACE &&
  kubectl get pods --namespace "$APP_NAMESPACE"
```

The resolver checks for the Trading schema initializer Job in both the application's
usual suffixed namespace and the environment namespace. It returns neither a guess
nor an ambiguous result. Stop if discovery fails; check the deployment and context.

The local recipes should produce in-cluster PostgreSQL and Mosquitto resources. The
local workload-identity recipe returns a compatible no-auth mapping.

### 5. Expose the K3s frontend

This command runs in the foreground:

**Bash:**

```bash
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps \
  --port 3000 \
  --remote-port 3000
```

Open <http://localhost:3000> and sign in with the prompted password. Press
<kbd>Ctrl</kbd>+<kbd>C</kbd> to stop the exposure before switching to AKS.

The browser path travels through Radius/Kubernetes port-forwarding over the Bastion API
tunnel. No inbound application port is opened on the K3s VM.

## Stage 3: Deploy the same model to AKS

### 1. Select AKS and its Radius control plane

**Bash:**

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod

test "$(kubectl config current-context)" = "aks-adaptive-apps"
test "$(rad workspace show --output json | jq -r '.connection.context')" = "aks-adaptive-apps"
rad env show env-azure-prod
```

### 2. Reuse Azure credentials and recipes

Challenge 03 registered federated Azure credentials for the AKS Radius control plane.
Verify them; do not create a client secret.

**Bash:**

```bash
rad credential show azure
rad recipe list \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod
```

The required resource types are the same as K3s, but their recipes should map to Azure
Database for PostgreSQL, Event Grid MQTT, and AKS workload identity. See
[Event Grid authentication and browser streaming](#event-grid-authentication-and-browser-streaming).

If the credential is missing, return to Challenge 03 and repeat its workload-identity
registration. Do not fall back to a long-lived service-principal secret.

### 3. Deploy the unchanged model

Use the same password for a direct UI comparison, but prompt again rather than retaining
it from the K3s command.

**Bash:**

```bash
read -rsp "Frontend password: " AUTH_PASSWORD
echo
rad deploy iac/app.bicep \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest \
  --parameters authUsername=admin \
  --parameters "authPassword=$AUTH_PASSWORD"
unset AUTH_PASSWORD
```

Azure Database for PostgreSQL can take several minutes to provision.

### 4. Validate AKS, Radius, and Azure resources

**Bash:**

```bash
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-<subscription-id>}"
export RESOURCE_GROUP="${RESOURCE_GROUP:-<lab-resource-group>}"
az account set --subscription "$AZURE_SUBSCRIPTION"

rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

APP_NAMESPACE="$(bash resources/resolve-trading-namespace.sh ws-azure-prod env-azure-prod)" &&
  export APP_NAMESPACE &&
  kubectl get pods --namespace "$APP_NAMESPACE"

az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

### 5. Expose the AKS frontend

The K3s exposure must already be stopped. Start a new foreground exposure against the
active AKS control plane:

**Bash:**

```bash
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps \
  --port 3002 \
  --remote-port 3000
```

Open <http://localhost:3002> and sign in with the credentials you passed to `rad deploy`:
the `authUsername` value (`admin`) and the `authPassword` you typed at the prompt. The
frontend checks these itself; Challenge 07 replaces them with an OIDC identity provider.

#### Place several trade orders

Do not stop at the dashboard. Place orders now, because they are the evidence that
[step 6](#6-prove-database-initialization-and-backend-readiness) reads back out of Azure:

1. Choose a symbol the backend offers at `/api/symbols`: `AAPL`, `MSFT`, `GOOGL`, `AMZN`,
   `TSLA`, `NVDA`, `META`, `NFLX`, `AMD`, or `INTC`.
2. Submit at least three **BUY** orders with different symbols and quantities. The
   backend stores each one with status `processed` and records a matching trade.
3. Optionally submit a **SELL** order for a symbol you do not hold. The backend rejects
   it server-side and stores it with status `rejected`, so the `orders` table ends up
   showing both outcomes.

The frontend posts these to the backend's `/api/orders` endpoint, and the backend writes
them to whatever database the `postgreSqlDatabases` recipe resolved to. On AKS that is a
managed Azure server outside the cluster, which is what makes step 6 worth running.

A reachable frontend and a complete Radius graph are the core proof. Order and trade
processing is supported in both environments. Event Grid on AKS requires a correctly
bound workload identity and the updated backend image; browser live streaming is a
separate limitation. See
[Event Grid authentication and browser streaming](#event-grid-authentication-and-browser-streaming).

### 6. Prove database initialization and backend readiness

Run this check for both AKS and K3s. Select the intended Kubernetes context and matching
Radius workspace using the target-selection commands above. Rediscover and export
`APP_NAMESPACE` each time you switch platforms; do not reuse the previous target's value.

In the AKS context:

```bash
APP_NAMESPACE="$(bash resources/resolve-trading-namespace.sh ws-azure-prod env-azure-prod)" &&
  export APP_NAMESPACE &&
  bash resources/verify-trading-db.sh
```

In the K3s context:

```bash
APP_NAMESPACE="$(bash resources/resolve-trading-namespace.sh ws-local-prod env-local-prod)" &&
  export APP_NAMESPACE &&
  bash resources/verify-trading-db.sh
```

Discovery selects a namespace only when exactly one candidate contains the Trading
initializer Job. Usually these are `env-azure-prod-adaptive-apps` and
`env-local-prod-adaptive-apps`; deployments directly in `env-azure-prod` or
`env-local-prod` are also supported. If both candidates match, inspect the Jobs and
explicitly export the intended namespace before running `verify-trading-db.sh`.

If verification reports `No trading-db schema initializer Job found`, it lists
matching Jobs in other namespaces of the current Kubernetes context and suggests
the corrected `export APP_NAMESPACE=...` command when there is one match. It stops
without switching namespaces or contexts. Multiple matches require your selection;
no matches may mean initialization was not deployed. Cross-namespace permission
failures are reported explicitly.

You will see the trading records entered in each environment. They differ only if
you placed different orders; identical records alone do not indicate a failure.

The first query lists `accounts`, `orders`, `positions`, and `trades`. The second returns
one row per order you placed in step 5:

```text
Order_id    Order_type    Placed_at                      Price    Quantity    Side    Status     Symbol
----------  ------------  -----------------------------  -------  ----------  ------  ---------  --------
1           MARKET        2026-09-02 12:34:15.020938+00  100.00   10          BUY     processed  AAPL
2           MARKET        2026-09-02 12:36:09.462464+00  384.04   10          BUY     processed  TSLA
```


> [!TIP]
> To avoid touching the firewall at all, add the client ip in the Azure portal OR run > the query from inside the cluster, whose egress IP the recipe already allowlisted. > This also avoids the CLI's table-rendering
> quirks, because you get raw `psql` output, and the pod deletes itself on exit:
>
> ```bash
> kubectl run pg-shell --namespace "$APP_NAMESPACE" --rm -i --restart=Never \
>   --image=postgres:16-alpine --env="PGPASSWORD=$PG_PASSWORD" \
>   -- psql "host=$PG_HOST dbname=$PG_DATABASE user=$PG_USER sslmode=require" \
>   -c "SELECT id, symbol, side, quantity, status FROM orders ORDER BY id;"
> ```
>
> ```text
>  id | symbol | side | quantity |  status
> ----+--------+------+----------+-----------
>   1 | AAPL   | BUY  |       10 | processed
>   2 | TSLA   | BUY  |       10 | processed
> (2 rows)
> ```

> [!WARNING]
> Delete the `workshop-client` firewall rule when you are finished. Leaving a public IP
> allowlisted on a database server outlives the workshop, and home or office IPs are
> reassigned to someone else.

## Stage 4: Compare the deployments

Stop the AKS exposure before running comparison commands.

### K3s evidence

**Bash:**

```bash
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-<subscription-id>}"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod

rad app graph --application adaptive-apps
rad resource list --application adaptive-apps
rad recipe list --environment env-local-prod
```

### AKS evidence

**Bash:**

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod

rad app graph --application adaptive-apps
rad resource list --application adaptive-apps
rad recipe list --environment env-azure-prod
```

### Expected comparison

| Area | K3s / `ws-local-prod` | AKS / `ws-azure-prod` |
| --- | --- | --- |
| Application file | `iac/app.bicep` | `iac/app.bicep` |
| Radius application | Independent `adaptive-apps` state | Independent `adaptive-apps` state |
| Database contract | `postgreSqlDatabases` | `postgreSqlDatabases` |
| Database implementation | In-cluster PostgreSQL | Azure Database for PostgreSQL |
| MQTT contract | `mqttBrokers` | `mqttBrokers` |
| MQTT implementation | In-cluster Mosquitto | Azure Event Grid MQTT |
| Workload identity | Local no-op mapping | Azure workload-identity mapping |
| AI | Disabled | Disabled |
| Access path | Port-forward over Bastion API tunnel | Port-forward to AKS API |
| Schema source | `iac/recipes/trading-schema.sql` | `iac/recipes/trading-schema.sql` |
| Seed result | One `Demo Account` | One `Demo Account` |

The application team owns `iac/app.bicep`, image versions, and safe deployment
parameters. The platform team owns the clusters, Radius control planes, environments,
Azure provider scope, resource types, recipes, and backing-service authorization.

## Troubleshooting

### `RecipeNotFoundFailure`

Run `rad recipe list --environment <environment>` in the matching workspace. Return to
Challenge 05 and deploy `iac/local-env.bicep` or `iac/aks-env.bicep`. Do not replace a
portable resource with a platform-specific declaration.

### `ServerNameAlreadyExists` for `trading-db`

Azure PostgreSQL server names are globally unique. Recipe `1.0.6` derived the name only
from the Radius resource ID, so another workshop with the same group, application, and
resource names could already own it. Do not delete the reported server; it can belong to
another workshop.

Confirm that this workshop has its own Azure resource group, then inspect the registration:

```bash
rad recipe list --environment env-azure-prod
```

For this fresh deployment, the registration must reference `postgres-azure-flex:1.0.8`.
If it does not, return to Challenge 05: publish the `1.0.8` recipes in Stage 2 and rerun
the Stage 3 `rad deploy iac/aks-env.bicep` command with the `1.0.8` PostgreSQL recipe
path. Verify the registration before retrying the unchanged AKS
`rad deploy iac/app.bicep` command from Stage 3 here. Retries use the same `1.0.8`
server name.

If the registration already uses `1.0.8`, check that the environment's Azure provider
scope is not shared with another workshop that uses the same Radius resource names.

### The deployment reached the wrong platform

Check all four dimensions:

```bash
kubectl config current-context
rad workspace list
rad group list
rad env show
```

Kubernetes context and Radius workspace are independent selectors.

### The deployment reported a failure that already succeeded

`rad deploy` can fail on a container that is actually healthy:

```text
"code": "Internal",
"message": "Container state is 'Waiting' Reason: CrashLoopBackOff, Message: back-off
5m0s restarting failed container=backend pod=backend-757d95b986-dbhw7"
```

or:

```text
"message": "deployment timed out, name: backend, namespace env-azure-prod-adaptive-apps,
error occurred while fetching latest status: client rate limiter Wait returned an error:
context deadline exceeded"
```

Radius polls the pods that already exist. When an earlier attempt left a pod crash-looping,
Kubernetes has backed that pod off by up to five minutes, so it does not restart promptly
even though the new specification is correct. Radius reads that stale status and gives up
while the replacement ReplicaSet is still rolling out.

**The tell-tale is the pod name.** If the hash in the error matches a pod from the previous
attempt rather than a newly created one, the status is stale. Check what is actually
running:

```bash
kubectl get pods --namespace "$APP_NAMESPACE"
kubectl get replicasets --namespace "$APP_NAMESPACE"
```

If a new pod is `1/1 Running`, the deployment succeeded and the error is a reporting
artifact; continue with the walkthrough. Otherwise simply run `rad deploy` again — the
back-off window has usually expired by then. Deleting the crash-looping pod first also
clears it.

### The cluster or the database stopped between sessions

Both Azure back ends can be stopped to save cost, and each fails in its own way. A stopped
AKS cluster stops resolving its API server name, so every `rad` and `kubectl` command
fails before it reaches Radius:

```text
Error: Get "https://<cluster>.hcp.<region>.azmk8s.io:443/apis/api.ucp.dev/v1alpha3":
dial tcp: lookup <cluster>.hcp.<region>.azmk8s.io: no such host
```

A stopped PostgreSQL Flexible Server instead surfaces as an opaque Azure error nested
inside the recipe deployment:

```text
"code": "RecipeDeploymentFailed",
"message": "failed to deploy recipe default of type Radius.Resources/postgreSqlDatabases"
...
"code": "InternalServerError",
"message": "An unexpected error occured while processing the request. Tracking ID: ..."
```

Neither is a defect in the application model. Start whichever is stopped and retry:

```bash
az aks show --resource-group "$RESOURCE_GROUP" --name "<cluster>" --query powerState.code -o tsv
az aks start --resource-group "$RESOURCE_GROUP" --name "<cluster>"

az postgres flexible-server show --resource-group "$RESOURCE_GROUP" \
  --name "<server>" --query state -o tsv
az postgres flexible-server start --resource-group "$RESOURCE_GROUP" --name "<server>"
```

If DNS still fails after the cluster is running, refresh the kubeconfig — a stale context
can point at a cluster that no longer exists:

```bash
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "<cluster>" --overwrite-existing
```

### K3s reports connection refused on localhost

The devcontainer restart stopped the tunnel process. Reconnect, then restore the
dedicated kubeconfig:

```bash
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-<subscription-id>}"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

### The generated extension is missing

Repeat Stage 1's `rad bicep publish-extension` command. The archive is generated and is
not committed.

<a id="why-aks-uses-mosquitto-for-mqttbrokers"></a>

### Event Grid authentication and browser streaming

Challenge 05 registers Azure Event Grid MQTT on AKS and Mosquitto on K3s. Use a backend
image containing
[microsoft/adaptive-apps#46](https://github.com/microsoft/adaptive-apps/pull/46).
That update sends the Entra token through MQTT v5 enhanced authentication
(`OAUTH2-JWT` and Authentication Data), derives the client identifier from the token's
`oid` claim, renews tokens, and reconnects without terminating the HTTP API.

The Event Grid and workload-identity recipes share the same namespace configured by
the environment. The application deploys the broker before identities so its `orders`
topic space exists when publish/subscribe permissions are created. Verify the pod's
service account matches its federated credential and that `iac/app.bicep` projects
the `api://AzureADTokenExchange` token at `AZURE_FEDERATED_TOKEN_FILE`.
A missing token, an incorrect subject,
or missing TopicSpaces roles still prevents messaging, even if the HTTP API is healthy.

Inspect the actual accounts and MQTT results after deployment:

```bash
kubectl get deployment backend frontend --namespace "$APP_NAMESPACE" \
  --output custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.template.spec.serviceAccountName
kubectl logs deployment/backend --namespace "$APP_NAMESPACE" --tail=100
```

Look for a successful MQTT CONNECT and subscription, not just a Ready pod. If the
accounts differ from the identity recipe's inputs, reapply Challenge 05's complete
environment deployment with `serviceAccountOverrides` set to the actual names.

`MQTT_AUTH_METHOD` and `MQTT_TOKEN_AUDIENCE` come from the broker resource, so K3s
continues to use the unauthenticated in-cluster Mosquitto path without an application
platform branch.

The browser MQTT-over-WebSocket client still connects without credentials and cannot
live-stream through Event Grid. Use the REST API/UI for the core demonstration;
browser live streaming requires a separate authenticated browser path or server relay.

### A second exposure cannot bind port 3000

Stop the previous `rad resource expose` process with <kbd>Ctrl</kbd>+<kbd>C</kbd>.
Switch context and workspace, then start the exposure again. A foreground exposure
belongs to the control plane active when it starts.
