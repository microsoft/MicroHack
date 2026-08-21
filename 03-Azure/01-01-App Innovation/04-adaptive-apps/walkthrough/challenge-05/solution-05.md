# Walkthrough Challenge 05 - Port the App Across Environments

[< Previous Solution](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Next Solution](../challenge-06/solution-06.md)

Duration: 45-75 minutes

## Coach notes

### How we arrived here

1. **Challenge 01 prepared two Kubernetes targets.** `aks-adaptive-apps` is the
   Azure-managed AKS target. `k3s-azure-vm` is the private K3s target used for the Local
   platform and reached through the Azure Bastion API tunnel.
2. **Challenge 02 installed two independent Radius control planes.** The local workspace
   `ws-azure-prod` targets AKS and contains `env-azure-prod`; `ws-local-prod` targets K3s
   and contains `env-local-prod`. Each control plane has its own `rg-trading` group.
   Identical names do not imply shared state.
3. **Challenge 03 established contracts and the shared platform baseline.** The `core`
   capability portfolio installed identity, observability, and the applicable Istio
   strict-mTLS baseline on each cluster. The challenge then registered the portable
   `Radius.Resources/*` resource-type contracts separately in both Radius control planes
   and generated the local `artifacts/types.tgz` Bicep extension. A contract describes
   application-facing inputs and recipe-produced outputs; registering it does not create
   PostgreSQL, Event Grid, or application containers.
4. **Challenge 04 registered environment-specific recipes.** For the contracts exercised
   here, the selected environment now determines these implementations:

   | Portable contract | `env-azure-prod` on AKS/Azure | `env-local-prod` on K3s |
   | --- | --- | --- |
   | `Radius.Resources/postgreSqlDatabases` | Azure Database for PostgreSQL Flexible Server | In-cluster PostgreSQL |
   | `Radius.Resources/mqttBrokers` | Azure Event Grid MQTT | In-cluster Eclipse Mosquitto |
   | `Radius.Resources/workloadIdentities` | Azure/AKS workload identity mapping | Local Kubernetes mapping/no-op implementation |

   Challenge 04 also prepared Keycloak, AI, governance, and agent-guardrail recipe
   mappings for later challenges; the Challenge 05 core model does not exercise all of
   them.

   > [!IMPORTANT]
   > The manually authored Azure SQL recipe in Challenge 04 is a teaching example for
   > `Radius.Resources/sqlDatabases`. The Trading application in `iac/app.bicep` requests
   > `Radius.Resources/postgreSqlDatabases`, so Radius uses the PostgreSQL recipes shown
   > above rather than the custom Azure SQL recipe.

5. **Challenge 05 deploys the Trading application for the first time.** The same
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
belongs to Challenge 06, service communication to Challenge 07, and AI to Challenge 08.
Do not provision per-workload managed identities or AI services here.

Deployment parity is not runtime parity. On AKS, recipe execution can create Azure
Database for PostgreSQL Flexible Server and Event Grid resources; on K3s it creates
in-cluster PostgreSQL and Mosquitto workloads. Event Grid MQTT still needs topic spaces,
permission bindings, and federated workload identities for end-to-end messaging. That
runtime work is deferred or discussed in later identity and communication challenges; a
green Radius deployment proves model portability, not complete messaging parity.

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

## Stage 1: Inspect the invariant application model

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

Challenge 03 generated `artifacts/types.tgz`. The archive is intentionally ignored by
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

**PowerShell 7:**

```powershell
New-Item -ItemType Directory -Path artifacts -Force | Out-Null
if (-not (Test-Path artifacts/types.tgz)) {
    $TypesFile = Join-Path ([System.IO.Path]::GetTempPath()) "adaptive-apps-types.yaml"
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/microsoft/adaptive-apps/885627980684e5bcc6fe4bbd2848c1ec247b0a0b/radius/resource-types/types.yaml" `
        -OutFile $TypesFile
    rad bicep publish-extension `
        --from-file $TypesFile `
        --target artifacts/types.tgz `
        --force
    Remove-Item $TypesFile -Force
}
```

`iac/bicepconfig.json` maps the `radiusResources` extension to this generated archive.
Do not commit `types.tgz`.

## Stage 2: Deploy to private K3s

### 1. Restore and select the K3s target

After every devcontainer restart, re-establish the tunnel before K3s commands.
PowerShell also invokes the provisioning tool through Bash because that tool remains a
Bash script.

**Bash:**

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
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

**PowerShell 7:**

```powershell
$env:AZURE_SUBSCRIPTION = "<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
$env:KUBECONFIG = "$HOME/.kube/adaptive-apps-k3s.yaml"

kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod

if ((kubectl config current-context) -ne "k3s-azure-vm") {
    throw "Kubernetes target drift: expected k3s-azure-vm."
}
$Workspace = rad workspace show --output json | ConvertFrom-Json
if ($Workspace.connection.context -ne "k3s-azure-vm") {
    throw "Radius target drift: ws-local-prod must target k3s-azure-vm."
}
rad env show env-local-prod
```

### 2. Verify the Challenge 04 handoff

**Bash:**

```bash
rad resource-type list
rad recipe list \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod
```

**PowerShell 7:**

```powershell
rad resource-type list
rad recipe list `
    --workspace ws-local-prod `
    --group rg-trading `
    --environment env-local-prod
```

Confirm default recipes exist for:

- `Radius.Resources/postgreSqlDatabases`
- `Radius.Resources/mqttBrokers`
- `Radius.Resources/workloadIdentities`

If one is missing, rerun the K3s portion of Challenge 04. Do not edit `iac/app.bicep`.

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

**PowerShell 7:**

```powershell
$SecurePassword = Read-Host "Frontend password" -AsSecureString
$Credential = [System.Management.Automation.PSCredential]::new("admin", $SecurePassword)
$PlainPassword = $Credential.GetNetworkCredential().Password
try {
    rad deploy iac/app.bicep `
        --workspace ws-local-prod `
        --group rg-trading `
        --environment env-local-prod `
        --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps `
        --parameters imageTag=latest `
        --parameters authUsername=admin `
        --parameters "authPassword=$PlainPassword"
}
finally {
    $PlainPassword = $null
    $Credential = $null
    $SecurePassword = $null
}
```

Do not save the password in a parameters file or command transcript.
The CLI argument is briefly visible to local process inspection, so run the lab only
on a trusted, single-user workstation or devcontainer host.

### 4. Validate graph, resources, and workloads

**Bash:**

```bash
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

ENV_NAMESPACE="$(rad env show env-local-prod --output json |
  jq -r '.properties.compute.namespace')"
APP_NAMESPACE="${ENV_NAMESPACE}-adaptive-apps"
kubectl get namespace "$APP_NAMESPACE" >/dev/null 2>&1 ||
  APP_NAMESPACE="$ENV_NAMESPACE"
kubectl get pods --namespace "$APP_NAMESPACE"
```

**PowerShell 7:**

```powershell
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

$Environment = rad env show env-local-prod --output json | ConvertFrom-Json
$EnvironmentNamespace = $Environment.properties.compute.namespace
$AppNamespace = "$EnvironmentNamespace-adaptive-apps"
kubectl get namespace $AppNamespace --no-headers *> $null
if ($LASTEXITCODE -ne 0) {
    $AppNamespace = $EnvironmentNamespace
}
kubectl get pods --namespace $AppNamespace
```

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

**PowerShell 7:**

```powershell
rad resource expose Applications.Core/containers frontend `
    --application adaptive-apps `
    --port 3000 `
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

**PowerShell 7:**

```powershell
Remove-Item Env:KUBECONFIG -ErrorAction SilentlyContinue
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod

if ((kubectl config current-context) -ne "aks-adaptive-apps") {
    throw "Kubernetes target drift: expected aks-adaptive-apps."
}
$Workspace = rad workspace show --output json | ConvertFrom-Json
if ($Workspace.connection.context -ne "aks-adaptive-apps") {
    throw "Radius target drift: ws-azure-prod must target aks-adaptive-apps."
}
rad env show env-azure-prod
```

### 2. Reuse Azure credentials and recipes

Challenge 02 registered federated Azure credentials for the AKS Radius control plane.
Verify them; do not create a client secret.

**Bash:**

```bash
rad credential show azure
rad recipe list \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod
```

**PowerShell 7:**

```powershell
rad credential show azure
rad recipe list `
    --workspace ws-azure-prod `
    --group rg-trading `
    --environment env-azure-prod
```

The required resource types are the same as K3s, but their recipes should map to Azure
Database for PostgreSQL, Azure Event Grid MQTT, and AKS workload identity.

If the credential is missing, return to Challenge 02 and repeat its workload-identity
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

**PowerShell 7:**

```powershell
$SecurePassword = Read-Host "Frontend password" -AsSecureString
$Credential = [System.Management.Automation.PSCredential]::new("admin", $SecurePassword)
$PlainPassword = $Credential.GetNetworkCredential().Password
try {
    rad deploy iac/app.bicep `
        --workspace ws-azure-prod `
        --group rg-trading `
        --environment env-azure-prod `
        --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps `
        --parameters imageTag=latest `
        --parameters authUsername=admin `
        --parameters "authPassword=$PlainPassword"
}
finally {
    $PlainPassword = $null
    $Credential = $null
    $SecurePassword = $null
}
```

Azure Database for PostgreSQL can take several minutes to provision.

### 4. Validate AKS, Radius, and Azure resources

**Bash:**

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export RESOURCE_GROUP="rg-adaptive-apps"
az account set --subscription "$AZURE_SUBSCRIPTION"

rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

ENV_NAMESPACE="$(rad env show env-azure-prod --output json |
  jq -r '.properties.compute.namespace')"
APP_NAMESPACE="${ENV_NAMESPACE}-adaptive-apps"
kubectl get namespace "$APP_NAMESPACE" >/dev/null 2>&1 ||
  APP_NAMESPACE="$ENV_NAMESPACE"
kubectl get pods --namespace "$APP_NAMESPACE"

az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --output table
```

**PowerShell 7:**

```powershell
$env:AZURE_SUBSCRIPTION = "<subscription-id>"
$env:RESOURCE_GROUP = "rg-adaptive-apps"
az account set --subscription $env:AZURE_SUBSCRIPTION

rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

$Environment = rad env show env-azure-prod --output json | ConvertFrom-Json
$EnvironmentNamespace = $Environment.properties.compute.namespace
$AppNamespace = "$EnvironmentNamespace-adaptive-apps"
kubectl get namespace $AppNamespace --no-headers *> $null
if ($LASTEXITCODE -ne 0) {
    $AppNamespace = $EnvironmentNamespace
}
kubectl get pods --namespace $AppNamespace

az resource list `
    --resource-group $env:RESOURCE_GROUP `
    --output table
```

### 5. Expose the AKS frontend

The K3s exposure must already be stopped. Start a new foreground exposure against the
active AKS control plane:

**Bash:**

```bash
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps \
  --port 3000 \
  --remote-port 3000
```

**PowerShell 7:**

```powershell
rad resource expose Applications.Core/containers frontend `
    --application adaptive-apps `
    --port 3000 `
    --remote-port 3000
```

Open <http://localhost:3000>. A reachable frontend and a complete Radius graph are the
core proof. MQTT-backed features can remain incomplete because Event Grid data-plane
authorization is outside this challenge's portability proof.

## Stage 4: Compare the deployments

Stop the AKS exposure before running comparison commands.

### K3s evidence

**Bash:**

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
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

**PowerShell 7:**

```powershell
$env:AZURE_SUBSCRIPTION = "<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
$env:KUBECONFIG = "$HOME/.kube/adaptive-apps-k3s.yaml"
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

**PowerShell 7:**

```powershell
Remove-Item Env:KUBECONFIG -ErrorAction SilentlyContinue
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

The application team owns `iac/app.bicep`, image versions, and safe deployment
parameters. The platform team owns the clusters, Radius control planes, environments,
Azure provider scope, resource types, recipes, and backing-service authorization.

## Troubleshooting

### `RecipeNotFoundFailure`

Run `rad recipe list --environment <environment>` in the matching workspace. Return to
Challenge 04 and deploy `iac/local-env.bicep` or `iac/aks-env.bicep`. Do not replace a
portable resource with a platform-specific declaration.

### The deployment reached the wrong platform

Check all four dimensions:

```bash
kubectl config current-context
rad workspace list
rad group list
rad env show
```

Kubernetes context and Radius workspace are independent selectors.

### K3s reports connection refused on localhost

The devcontainer restart stopped the tunnel process. Reconnect, then restore the
dedicated kubeconfig:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
```

In PowerShell, set `$env:AZURE_SUBSCRIPTION`, invoke the same script through `bash`, and
set `$env:KUBECONFIG`.

### The generated extension is missing

Repeat Stage 1's `rad bicep publish-extension` command. The archive is generated and is
not committed.

### The frontend is reachable but MQTT features fail on AKS

This is the documented runtime gap. The Azure recipe creates the Event Grid namespace
and endpoint, but secure publish/subscribe also needs topic spaces, permission bindings,
federated credentials, and appropriate Event Grid data-plane roles. Preserve the
identity boundary and track this as separate platform work rather than adding shared
secrets. Challenge 06 addresses end-user authentication, not MQTT authorization.

### A second exposure cannot bind port 3000

Stop the previous `rad resource expose` process with <kbd>Ctrl</kbd>+<kbd>C</kbd>.
Switch context and workspace, then start the exposure again. A foreground exposure
belongs to the control plane active when it starts.
