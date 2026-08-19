# Walkthrough Challenge 08 - Adapt AI Services

[< Previous Challenge](../../challenges/challenge-07.md) - **[Home](../../Readme.md)** - [Next Challenge >](../../challenges/challenge-09.md)

Duration: 60-90 minutes

## Coach notes

The source Student Challenge 08 contains only generic challenge boilerplate, and its
Coach Solution 08 is empty. This walkthrough reconstructs the intended **Adapt AI
Services** outcome from the Adaptive Apps AI resource contract, recipes, application,
and `ai-agent` runtime.

The default workshop topology makes the source Kaito implementation unsuitable for the
core path: `Standard_D4s_v5` has no GPU, while the Kaito recipe schedules only to a node
with `nvidia.com/gpu=true`. The source Azure OpenAI recipe also returns an account key.
This adaptation therefore uses:

| Target | Recipe implementation | Authentication |
| --- | --- | --- |
| Private K3s | CPU-only Ollama with `qwen2.5:0.5b` | In-cluster endpoint; no credential |
| AKS | Reference to an existing Azure OpenAI deployment | AKS workload identity |

The K3s model is deliberately small enough to demonstrate the contract, not suitable for
financial advice or production quality evaluation. The AKS path does not create an Azure
OpenAI account or deployment, avoiding unexpected quota and cost. A participant must
select an existing, approved deployment.

Challenge 07 owns service-mesh authorization and OPA policy. Do not add its governance
resources here. Challenge 08 focuses on model selection, recipes, workload identity,
provider substitution, and runtime evidence.

## Fixed target map

| Platform | Kubernetes context | Radius workspace | Environment | Radius group |
| --- | --- | --- | --- | --- |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

Each Radius control plane has independent application state and can only reach the
ClusterIP recipe registry in its own cluster. Publish and register the correct recipe
after selecting each target.

## Stage 1: Understand and validate the stable contract

`iac/ai.bicep` adds two resources to the existing `adaptive-apps` application:

| Resource | Stable intent |
| --- | --- |
| `trading-ai` | A `Radius.Resources/aiModels` capability with a requested model |
| `ai-agent` | The same published agent image connected to `trading-ai` |

The recipe supplies `provider`, `endpoint`, `model`, and `secrets.apiKey`. Radius
connections inject the first three values as:

```text
CONNECTION_AI_PROVIDER
CONNECTION_AI_ENDPOINT
CONNECTION_AI_MODEL
```

`iac/ai.bicep` explicitly maps the optional API-key output to
`CONNECTION_AI_SECRETS_APIKEY`. Both core recipes return an empty value. The K3s provider
needs no credential; the Azure provider uses `DefaultAzureCredential` and the projected
AKS workload-identity token.

The optional service-account and workload-identity parameters default to disabled, so
omitting those identity parameters remains valid on K3s. The portable `aiModel`
parameter is still required for every target.

### Generate the custom Bicep extension

The `Radius.Resources/aiModels` type is part of the Challenge 03 catalog. Recreate its
ignored local archive if it is not already present.

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

Compile without deploying:

**Bash:**

```bash
az bicep build --file iac/ai.bicep --stdout >/dev/null
az bicep build --file iac/recipes/ai-model-local-cpu.bicep --stdout >/dev/null
az bicep build --file iac/recipes/ai-model-azure-existing.bicep --stdout >/dev/null
```

**PowerShell 7:**

```powershell
az bicep build --file iac/ai.bicep --stdout | Out-Null
az bicep build --file iac/recipes/ai-model-local-cpu.bicep --stdout | Out-Null
az bicep build --file iac/recipes/ai-model-azure-existing.bicep --stdout | Out-Null
```

`iac/bicepconfig.json` resolves the generated extension. Do not commit `types.tgz`.

## Stage 2: Run the CPU model on private K3s

### 1. Restore and verify the K3s target

The dedicated kubeconfig points to a localhost API endpoint maintained by Azure Bastion.
Restore the tunnel after every devcontainer restart.

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

This tunnel exposes only the Kubernetes API on localhost. It does not make the private
VM, registry, model endpoint, or application publicly reachable.

### 2. Deploy the workshop recipe registry

Apply the pinned registry manifest and wait for it to become healthy:

```bash
kubectl apply --filename resources/local-recipe-registry.yaml
kubectl rollout status \
  deployment/recipe-registry \
  --namespace adaptive-recipes \
  --timeout=5m
kubectl get service recipe-registry --namespace adaptive-recipes
```

The registry is unauthenticated but `ClusterIP`-only. Its storage is `emptyDir`, so a
registry-pod replacement requires the recipe to be published again. This is a focused
workshop transport, not a production registry pattern.

In **Terminal A**, set the dedicated K3s kubeconfig again because environment variables
do not carry into a new terminal. Keep the port-forward in the foreground.

**Bash:**

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl port-forward \
  service/recipe-registry \
  --namespace adaptive-recipes \
  5000:5000
```

**PowerShell 7:**

```powershell
$env:KUBECONFIG = "$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl port-forward `
    service/recipe-registry `
    --namespace adaptive-recipes `
    5000:5000
```

In **Terminal B**, publish the K3s recipe through localhost and register the cluster-DNS
path that the active Radius control plane can resolve.

**Bash:**

```bash
curl --fail --silent http://127.0.0.1:5000/v2/ >/dev/null

rad bicep publish \
  --file iac/recipes/ai-model-local-cpu.bicep \
  --target br:127.0.0.1:5000/adaptive-apps/ai-model-local-cpu:1.0.0 \
  --plain-http

rad recipe register default \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod \
  --resource-type Radius.Resources/aiModels \
  --template-kind bicep \
  --template-path recipe-registry.adaptive-recipes.svc.cluster.local:5000/adaptive-apps/ai-model-local-cpu:1.0.0 \
  --plain-http

rad recipe list \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod
```

**PowerShell 7:**

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:5000/v2/ | Out-Null

rad bicep publish `
    --file iac/recipes/ai-model-local-cpu.bicep `
    --target br:127.0.0.1:5000/adaptive-apps/ai-model-local-cpu:1.0.0 `
    --plain-http

rad recipe register default `
    --workspace ws-local-prod `
    --group rg-trading `
    --environment env-local-prod `
    --resource-type Radius.Resources/aiModels `
    --template-kind bicep `
    --template-path recipe-registry.adaptive-recipes.svc.cluster.local:5000/adaptive-apps/ai-model-local-cpu:1.0.0 `
    --plain-http

rad recipe list `
    --workspace ws-local-prod `
    --group rg-trading `
    --environment env-local-prod
```

After registration succeeds, stop Terminal A with <kbd>Ctrl</kbd>+<kbd>C>. Radius uses
the in-cluster service path during deployment; the participant-side forward is no longer
needed.

### 3. Deploy the additive AI model

Use the compact default model. `iac/ai.bicep` is the same file later deployed to AKS.

**Bash:**

```bash
rad deploy iac/ai.bicep \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest \
  --parameters aiModel=qwen2.5:0.5b
```

**PowerShell 7:**

```powershell
rad deploy iac/ai.bicep `
    --workspace ws-local-prod `
    --group rg-trading `
    --environment env-local-prod `
    --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps `
    --parameters imageTag=latest `
    --parameters aiModel=qwen2.5:0.5b
```

The model recipe creates an Ollama Deployment and Service. The first startup downloads
the model from the Ollama model registry and can take several minutes. Outbound network
access is therefore required even though inference runs in the K3s cluster afterward.

### 4. Validate the graph, model, and agent

Resolve the application namespace from the active environment, then find the model
Deployment by its recipe label.

**Bash:**

```bash
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

ENV_NAMESPACE="$(rad env show env-local-prod --output json |
  jq -r '.properties.compute.namespace')"
APP_NAMESPACE="${ENV_NAMESPACE}-adaptive-apps"
kubectl get namespace "$APP_NAMESPACE" >/dev/null 2>&1 ||
  APP_NAMESPACE="$ENV_NAMESPACE"

MODEL_DEPLOYMENT="$(kubectl get deployments \
  --namespace "$APP_NAMESPACE" \
  --selector resource=trading-ai \
  --output jsonpath='{.items[0].metadata.name}')"
test -n "$MODEL_DEPLOYMENT"

kubectl rollout status \
  "deployment/$MODEL_DEPLOYMENT" \
  --namespace "$APP_NAMESPACE" \
  --timeout=15m
kubectl rollout status \
  deployment/ai-agent \
  --namespace "$APP_NAMESPACE" \
  --timeout=5m
kubectl get pods,services --namespace "$APP_NAMESPACE"
kubectl get deployment "$MODEL_DEPLOYMENT" \
  --namespace "$APP_NAMESPACE" \
  --output json |
  jq '{requests: .spec.template.spec.containers[0].resources.requests,
       limits: .spec.template.spec.containers[0].resources.limits,
       startupProbe: .spec.template.spec.containers[0].startupProbe}'
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

$ModelDeployment = kubectl get deployments `
    --namespace $AppNamespace `
    --selector resource=trading-ai `
    --output jsonpath='{.items[0].metadata.name}'
if ([string]::IsNullOrWhiteSpace($ModelDeployment)) {
    throw "The trading-ai recipe did not create a model Deployment."
}

kubectl rollout status `
    "deployment/$ModelDeployment" `
    --namespace $AppNamespace `
    --timeout=15m
kubectl rollout status `
    deployment/ai-agent `
    --namespace $AppNamespace `
    --timeout=5m
kubectl get pods,services --namespace $AppNamespace

$ModelSpec = kubectl get deployment $ModelDeployment `
    --namespace $AppNamespace `
    --output json | ConvertFrom-Json
$ModelContainer = $ModelSpec.spec.template.spec.containers[0]
$ModelContainer.resources
$ModelContainer.startupProbe
```

If startup times out, inspect the model container without printing any application
credentials:

```bash
kubectl logs \
  "deployment/$MODEL_DEPLOYMENT" \
  --namespace "$APP_NAMESPACE" \
  --tail=100
```

The recipe requests `500m` CPU and `2Gi` memory and limits the model to four CPUs and
`8Gi`. Its `emptyDir` model cache is lost when the pod is replaced.

### 5. Validate inference

Expose only the `ai-agent` through the active Radius control plane. Run the command in a
foreground terminal:

**Bash:**

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
rad workspace switch ws-local-prod
rad resource expose Applications.Core/containers ai-agent \
  --application adaptive-apps \
  --port 7000 \
  --remote-port 7000
```

**PowerShell 7:**

```powershell
$env:KUBECONFIG = "$HOME/.kube/adaptive-apps-k3s.yaml"
rad workspace switch ws-local-prod
rad resource expose Applications.Core/containers ai-agent `
    --application adaptive-apps `
    --port 7000 `
    --remote-port 7000
```

From another terminal, validate configuration, inference, and input handling.

**Bash:**

```bash
curl --fail --silent --show-error http://127.0.0.1:7000/health | jq

curl --fail --silent --show-error \
  --request POST \
  --header 'Content-Type: application/json' \
  --data '{"question":"List two questions to ask before evaluating a stock."}' \
  http://127.0.0.1:7000/advice |
  jq

curl --silent --show-error \
  --write-out '\nHTTP %{http_code}\n' \
  --request POST \
  --header 'Content-Type: application/json' \
  --data '{"question":""}' \
  http://127.0.0.1:7000/advice
```

**PowerShell 7:**

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:7000/health

$AdviceBody = @{
    question = "List two questions to ask before evaluating a stock."
} | ConvertTo-Json
Invoke-RestMethod `
    -Method Post `
    -Uri http://127.0.0.1:7000/advice `
    -ContentType "application/json" `
    -Body $AdviceBody
$AdviceBody = $null

$BadRequest = Invoke-WebRequest `
    -Method Post `
    -Uri http://127.0.0.1:7000/advice `
    -ContentType "application/json" `
    -Body '{"question":""}' `
    -SkipHttpErrorCheck
if ($BadRequest.StatusCode -ne 400) {
    throw "Expected the empty question to return HTTP 400."
}
$BadRequest.StatusCode
```

The exact answer is non-deterministic. Validate the response shape and status, not a
specific sentence. Do not use confidential data in prompts. Stop the foreground
exposure before continuing.

## Stage 3: Use an existing Azure OpenAI deployment from AKS

### 1. Select AKS and verify the approved model deployment

Clear the K3s-only kubeconfig before selecting AKS.

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

Set the workshop and pre-existing Azure OpenAI values. The deployment name is a
participant-selected Azure resource child name, not necessarily the underlying model
name.

**Bash:**

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export RESOURCE_GROUP="rg-adaptive-apps"
export AKS_NAME="aks-adaptive-apps"
export OPENAI_RESOURCE_GROUP="<existing-openai-resource-group>"
export OPENAI_ACCOUNT="<existing-openai-account>"
export OPENAI_DEPLOYMENT="<existing-deployment-name>"
export AI_IDENTITY_NAME="id-adaptive-apps-ai"

az account set --subscription "$AZURE_SUBSCRIPTION"
test "$(az provider show \
  --namespace Microsoft.CognitiveServices \
  --query registrationState \
  --output tsv)" = "Registered"

OPENAI_ACCOUNT_JSON="$(az cognitiveservices account show \
  --resource-group "$OPENAI_RESOURCE_GROUP" \
  --name "$OPENAI_ACCOUNT" \
  --output json)"
OPENAI_ID="$(jq -er '.id' <<<"$OPENAI_ACCOUNT_JSON")"
OPENAI_ENDPOINT="$(jq -er '.properties.endpoint' <<<"$OPENAI_ACCOUNT_JSON")"
OPENAI_LOCATION="$(jq -er '.location' <<<"$OPENAI_ACCOUNT_JSON")"
OPENAI_KIND="$(jq -er '.kind' <<<"$OPENAI_ACCOUNT_JSON")"
case "$OPENAI_KIND" in
  OpenAI|AIServices) ;;
  *) echo "Unsupported account kind: $OPENAI_KIND" >&2; exit 1 ;;
esac

DEPLOYMENT_JSON="$(az cognitiveservices account deployment show \
  --resource-group "$OPENAI_RESOURCE_GROUP" \
  --name "$OPENAI_ACCOUNT" \
  --deployment-name "$OPENAI_DEPLOYMENT" \
  --output json)"
jq --arg location "$OPENAI_LOCATION" '{
  accountLocation: $location,
  deploymentName: .name,
  model: .properties.model.name,
  modelVersion: .properties.model.version,
  sku: .sku.name,
  capacity: .sku.capacity
}' <<<"$DEPLOYMENT_JSON"

AKS_OIDC_ISSUER="$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --query oidcIssuerProfile.issuerUrl \
  --output tsv)"
WORKLOAD_IDENTITY_ENABLED="$(az aks show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --query securityProfile.workloadIdentity.enabled \
  --output tsv)"
test -n "$AKS_OIDC_ISSUER"
test "$WORKLOAD_IDENTITY_ENABLED" = "true"
```

**PowerShell 7:**

```powershell
$env:AZURE_SUBSCRIPTION = "<subscription-id>"
$env:RESOURCE_GROUP = "rg-adaptive-apps"
$env:AKS_NAME = "aks-adaptive-apps"
$env:OPENAI_RESOURCE_GROUP = "<existing-openai-resource-group>"
$env:OPENAI_ACCOUNT = "<existing-openai-account>"
$env:OPENAI_DEPLOYMENT = "<existing-deployment-name>"
$env:AI_IDENTITY_NAME = "id-adaptive-apps-ai"

az account set --subscription $env:AZURE_SUBSCRIPTION
$ProviderState = az provider show `
    --namespace Microsoft.CognitiveServices `
    --query registrationState `
    --output tsv
if ($ProviderState -ne "Registered") {
    throw "Microsoft.CognitiveServices is not registered."
}

$OpenAiAccount = az cognitiveservices account show `
    --resource-group $env:OPENAI_RESOURCE_GROUP `
    --name $env:OPENAI_ACCOUNT `
    --output json | ConvertFrom-Json
if ($OpenAiAccount.kind -notin @("OpenAI", "AIServices")) {
    throw "Unsupported account kind: $($OpenAiAccount.kind)"
}
$OpenAiId = $OpenAiAccount.id
$OpenAiEndpoint = $OpenAiAccount.properties.endpoint
$OpenAiLocation = $OpenAiAccount.location

$OpenAiDeployment = az cognitiveservices account deployment show `
    --resource-group $env:OPENAI_RESOURCE_GROUP `
    --name $env:OPENAI_ACCOUNT `
    --deployment-name $env:OPENAI_DEPLOYMENT `
    --output json | ConvertFrom-Json
[pscustomobject]@{
    AccountLocation = $OpenAiLocation
    DeploymentName = $OpenAiDeployment.name
    Model = $OpenAiDeployment.properties.model.name
    ModelVersion = $OpenAiDeployment.properties.model.version
    Sku = $OpenAiDeployment.sku.name
    Capacity = $OpenAiDeployment.sku.capacity
}

$AksOidcIssuer = az aks show `
    --resource-group $env:RESOURCE_GROUP `
    --name $env:AKS_NAME `
    --query oidcIssuerProfile.issuerUrl `
    --output tsv
$WorkloadIdentityEnabled = az aks show `
    --resource-group $env:RESOURCE_GROUP `
    --name $env:AKS_NAME `
    --query securityProfile.workloadIdentity.enabled `
    --output tsv
if ([string]::IsNullOrWhiteSpace($AksOidcIssuer)) {
    throw "AKS OIDC issuer is not enabled."
}
if ($WorkloadIdentityEnabled -ne "true") {
    throw "AKS workload identity is not enabled."
}
```

Confirm the selected deployment is approved for the workshop, has available quota, and
is reachable from AKS under its network policy. This challenge does not change the
deployment SKU, capacity, filters, or lifecycle.

### 2. Publish and register the Azure reference recipe

Deploy the registry to AKS:

```bash
kubectl apply --filename resources/local-recipe-registry.yaml
kubectl rollout status \
  deployment/recipe-registry \
  --namespace adaptive-recipes \
  --timeout=5m
```

In **Terminal A**, run the AKS registry port-forward:

```bash
kubectl port-forward \
  service/recipe-registry \
  --namespace adaptive-recipes \
  5000:5000
```

In **Terminal B**, publish and register the Azure recipe.

**Bash:**

```bash
curl --fail --silent http://127.0.0.1:5000/v2/ >/dev/null

rad bicep publish \
  --file iac/recipes/ai-model-azure-existing.bicep \
  --target br:127.0.0.1:5000/adaptive-apps/ai-model-azure-existing:1.0.0 \
  --plain-http

rad recipe register default \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod \
  --resource-type Radius.Resources/aiModels \
  --template-kind bicep \
  --template-path recipe-registry.adaptive-recipes.svc.cluster.local:5000/adaptive-apps/ai-model-azure-existing:1.0.0 \
  --parameters "endpoint=$OPENAI_ENDPOINT" \
  --parameters "deploymentName=$OPENAI_DEPLOYMENT" \
  --plain-http

rad recipe list \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod
```

**PowerShell 7:**

```powershell
Invoke-WebRequest -Uri http://127.0.0.1:5000/v2/ | Out-Null

rad bicep publish `
    --file iac/recipes/ai-model-azure-existing.bicep `
    --target br:127.0.0.1:5000/adaptive-apps/ai-model-azure-existing:1.0.0 `
    --plain-http

rad recipe register default `
    --workspace ws-azure-prod `
    --group rg-trading `
    --environment env-azure-prod `
    --resource-type Radius.Resources/aiModels `
    --template-kind bicep `
    --template-path recipe-registry.adaptive-recipes.svc.cluster.local:5000/adaptive-apps/ai-model-azure-existing:1.0.0 `
    --parameters "endpoint=$OpenAiEndpoint" `
    --parameters "deploymentName=$env:OPENAI_DEPLOYMENT" `
    --plain-http

rad recipe list `
    --workspace ws-azure-prod `
    --group rg-trading `
    --environment env-azure-prod
```

The endpoint and deployment name are configuration, not credentials. The recipe returns
no API key. Stop Terminal A after registration.

### 3. Create the exact application workload identity

First derive the existing Radius application namespace. It is part of the federated
subject and must match exactly.

**Bash:**

```bash
ENV_NAMESPACE="$(rad env show env-azure-prod --output json |
  jq -r '.properties.compute.namespace')"
APP_NAMESPACE="${ENV_NAMESPACE}-adaptive-apps"
kubectl get namespace "$APP_NAMESPACE" >/dev/null 2>&1 ||
  APP_NAMESPACE="$ENV_NAMESPACE"
kubectl get namespace "$APP_NAMESPACE"

SERVICE_ACCOUNT_NAME="ai-agent"
FEDERATED_CREDENTIAL_NAME="adaptive-apps-ai-agent"
FEDERATED_SUBJECT="system:serviceaccount:${APP_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"

if ! az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_IDENTITY_NAME" >/dev/null 2>&1; then
  az identity create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AI_IDENTITY_NAME" \
    --location "$(az aks show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$AKS_NAME" \
      --query location \
      --output tsv)" >/dev/null
fi

IDENTITY_JSON="$(az identity show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_IDENTITY_NAME" \
  --output json)"
AI_CLIENT_ID="$(jq -er '.clientId' <<<"$IDENTITY_JSON")"
AI_PRINCIPAL_ID="$(jq -er '.principalId' <<<"$IDENTITY_JSON")"
TENANT_ID="$(az account show --query tenantId --output tsv)"

if az identity federated-credential show \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$AI_IDENTITY_NAME" \
  --name "$FEDERATED_CREDENTIAL_NAME" >/dev/null 2>&1; then
  az identity federated-credential update \
    --resource-group "$RESOURCE_GROUP" \
    --identity-name "$AI_IDENTITY_NAME" \
    --name "$FEDERATED_CREDENTIAL_NAME" \
    --issuer "$AKS_OIDC_ISSUER" \
    --subject "$FEDERATED_SUBJECT" \
    --audiences api://AzureADTokenExchange >/dev/null
else
  az identity federated-credential create \
    --resource-group "$RESOURCE_GROUP" \
    --identity-name "$AI_IDENTITY_NAME" \
    --name "$FEDERATED_CREDENTIAL_NAME" \
    --issuer "$AKS_OIDC_ISSUER" \
    --subject "$FEDERATED_SUBJECT" \
    --audiences api://AzureADTokenExchange >/dev/null
fi

kubectl create serviceaccount "$SERVICE_ACCOUNT_NAME" \
  --namespace "$APP_NAMESPACE" \
  --dry-run=client \
  --output yaml |
  kubectl apply --filename -
kubectl annotate serviceaccount "$SERVICE_ACCOUNT_NAME" \
  --namespace "$APP_NAMESPACE" \
  "azure.workload.identity/client-id=$AI_CLIENT_ID" \
  --overwrite
```

**PowerShell 7:**

```powershell
$Environment = rad env show env-azure-prod --output json | ConvertFrom-Json
$EnvironmentNamespace = $Environment.properties.compute.namespace
$AppNamespace = "$EnvironmentNamespace-adaptive-apps"
kubectl get namespace $AppNamespace --no-headers *> $null
if ($LASTEXITCODE -ne 0) {
    $AppNamespace = $EnvironmentNamespace
}
kubectl get namespace $AppNamespace

$ServiceAccountName = "ai-agent"
$FederatedCredentialName = "adaptive-apps-ai-agent"
$FederatedSubject = "system:serviceaccount:${AppNamespace}:${ServiceAccountName}"

az identity show `
    --resource-group $env:RESOURCE_GROUP `
    --name $env:AI_IDENTITY_NAME *> $null
if ($LASTEXITCODE -ne 0) {
    $AksLocation = az aks show `
        --resource-group $env:RESOURCE_GROUP `
        --name $env:AKS_NAME `
        --query location `
        --output tsv
    az identity create `
        --resource-group $env:RESOURCE_GROUP `
        --name $env:AI_IDENTITY_NAME `
        --location $AksLocation | Out-Null
}

$Identity = az identity show `
    --resource-group $env:RESOURCE_GROUP `
    --name $env:AI_IDENTITY_NAME `
    --output json | ConvertFrom-Json
$AiClientId = $Identity.clientId
$AiPrincipalId = $Identity.principalId
$TenantId = az account show --query tenantId --output tsv

az identity federated-credential show `
    --resource-group $env:RESOURCE_GROUP `
    --identity-name $env:AI_IDENTITY_NAME `
    --name $FederatedCredentialName *> $null
if ($LASTEXITCODE -eq 0) {
    az identity federated-credential update `
        --resource-group $env:RESOURCE_GROUP `
        --identity-name $env:AI_IDENTITY_NAME `
        --name $FederatedCredentialName `
        --issuer $AksOidcIssuer `
        --subject $FederatedSubject `
        --audiences api://AzureADTokenExchange | Out-Null
}
else {
    az identity federated-credential create `
        --resource-group $env:RESOURCE_GROUP `
        --identity-name $env:AI_IDENTITY_NAME `
        --name $FederatedCredentialName `
        --issuer $AksOidcIssuer `
        --subject $FederatedSubject `
        --audiences api://AzureADTokenExchange | Out-Null
}

kubectl create serviceaccount $ServiceAccountName `
    --namespace $AppNamespace `
    --dry-run=client `
    --output yaml |
    kubectl apply --filename -
kubectl annotate serviceaccount $ServiceAccountName `
    --namespace $AppNamespace `
    "azure.workload.identity/client-id=$AiClientId" `
    --overwrite
```

Assign only the data-plane inference role at the selected account scope.

**Bash:**

```bash
ROLE_NAME="Cognitive Services OpenAI User"
ROLE_ASSIGNMENT_ID="$(az role assignment list \
  --scope "$OPENAI_ID" \
  --query "[?principalId=='$AI_PRINCIPAL_ID' && roleDefinitionName=='$ROLE_NAME'].id | [0]" \
  --output tsv)"
if [ -z "$ROLE_ASSIGNMENT_ID" ]; then
  az role assignment create \
    --assignee-object-id "$AI_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$ROLE_NAME" \
    --scope "$OPENAI_ID" >/dev/null
fi
```

**PowerShell 7:**

```powershell
$RoleName = "Cognitive Services OpenAI User"
$RoleQuery = "[?principalId=='$AiPrincipalId' && roleDefinitionName=='$RoleName'].id | [0]"
$RoleAssignmentId = az role assignment list `
    --scope $OpenAiId `
    --query $RoleQuery `
    --output tsv
if ([string]::IsNullOrWhiteSpace($RoleAssignmentId)) {
    az role assignment create `
        --assignee-object-id $AiPrincipalId `
        --assignee-principal-type ServicePrincipal `
        --role $RoleName `
        --scope $OpenAiId | Out-Null
}
```

This identity is for the application pod. It is separate from the Challenge 02 Radius
control-plane identity that deploys Azure resources.

### 4. Deploy the same AI application addition

Enable the AKS-only metadata and pass the exact service account and managed identity.

**Bash:**

```bash
rad deploy iac/ai.bicep \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest \
  --parameters "aiModel=$OPENAI_DEPLOYMENT" \
  --parameters "aiAgentServiceAccountName=$SERVICE_ACCOUNT_NAME" \
  --parameters enableAzureWorkloadIdentity=true \
  --parameters "aiAgentClientId=$AI_CLIENT_ID" \
  --parameters "workloadIdentityTenantId=$TENANT_ID"
```

**PowerShell 7:**

```powershell
rad deploy iac/ai.bicep `
    --workspace ws-azure-prod `
    --group rg-trading `
    --environment env-azure-prod `
    --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps `
    --parameters imageTag=latest `
    --parameters "aiModel=$env:OPENAI_DEPLOYMENT" `
    --parameters "aiAgentServiceAccountName=$ServiceAccountName" `
    --parameters enableAzureWorkloadIdentity=true `
    --parameters "aiAgentClientId=$AiClientId" `
    --parameters "workloadIdentityTenantId=$TenantId"
```

The Azure recipe references the existing account; it creates no Azure AI resource and
returns no key. Azure role propagation can take several minutes even after deployment
succeeds.

### 5. Validate federation and inference

Inspect the Radius graph and pod metadata without printing the projected token.

**Bash:**

```bash
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

kubectl rollout status \
  deployment/ai-agent \
  --namespace "$APP_NAMESPACE" \
  --timeout=5m
AI_POD="$(kubectl get pods \
  --namespace "$APP_NAMESPACE" \
  --output json |
  jq -r '.items[] |
    select(.spec.serviceAccountName == "ai-agent") |
    .metadata.name' |
  head -n 1)"
test -n "$AI_POD"

kubectl get serviceaccount ai-agent \
  --namespace "$APP_NAMESPACE" \
  --output json |
  jq '{name: .metadata.name,
       clientId: .metadata.annotations["azure.workload.identity/client-id"]}'
kubectl get pod "$AI_POD" \
  --namespace "$APP_NAMESPACE" \
  --output json |
  jq '{serviceAccount: .spec.serviceAccountName,
       workloadIdentity:
         .metadata.labels["azure.workload.identity/use"],
       projectedVolumeNames:
         [.spec.volumes[]? | select(.projected != null) | .name]}'

az identity federated-credential show \
  --resource-group "$RESOURCE_GROUP" \
  --identity-name "$AI_IDENTITY_NAME" \
  --name "$FEDERATED_CREDENTIAL_NAME" \
  --query '{issuer:issuer,subject:subject,audiences:audiences}' \
  --output json
az role assignment list \
  --scope "$OPENAI_ID" \
  --query "[?principalId=='$AI_PRINCIPAL_ID'].{role:roleDefinitionName,scope:scope}" \
  --output table
```

**PowerShell 7:**

```powershell
rad app graph --application adaptive-apps
rad resource list --application adaptive-apps

kubectl rollout status `
    deployment/ai-agent `
    --namespace $AppNamespace `
    --timeout=5m
$Pods = kubectl get pods `
    --namespace $AppNamespace `
    --output json | ConvertFrom-Json
$AiPod = @(
    $Pods.items |
        Where-Object { $_.spec.serviceAccountName -eq "ai-agent" }
)[0]
if ($null -eq $AiPod) {
    throw "No ai-agent pod using the expected service account was found."
}

$ServiceAccount = kubectl get serviceaccount ai-agent `
    --namespace $AppNamespace `
    --output json | ConvertFrom-Json
[pscustomobject]@{
    Name = $ServiceAccount.metadata.name
    ClientId = $ServiceAccount.metadata.annotations.'azure.workload.identity/client-id'
}
[pscustomobject]@{
    ServiceAccount = $AiPod.spec.serviceAccountName
    WorkloadIdentity = $AiPod.metadata.labels.'azure.workload.identity/use'
    ProjectedVolumeNames = @(
        $AiPod.spec.volumes |
            Where-Object { $null -ne $_.projected } |
            ForEach-Object name
    )
}

az identity federated-credential show `
    --resource-group $env:RESOURCE_GROUP `
    --identity-name $env:AI_IDENTITY_NAME `
    --name $FederatedCredentialName `
    --query '{issuer:issuer,subject:subject,audiences:audiences}' `
    --output json
$RoleQuery = "[?principalId=='$AiPrincipalId'].{role:roleDefinitionName,scope:scope}"
az role assignment list `
    --scope $OpenAiId `
    --query $RoleQuery `
    --output table
```

Do not `cat` the projected token or print environment variables that may contain
credentials.

Expose `ai-agent` in a foreground terminal:

**Bash:**

```bash
rad resource expose Applications.Core/containers ai-agent \
  --application adaptive-apps \
  --port 7000 \
  --remote-port 7000
```

**PowerShell 7:**

```powershell
rad resource expose Applications.Core/containers ai-agent `
    --application adaptive-apps `
    --port 7000 `
    --remote-port 7000
```

From another terminal, repeat the `/health`, `/advice`, and empty-question requests from
Stage 2. `/health` should report provider `azure` and the selected deployment name.
`/advice` proves both token exchange and model authorization. Stop the exposure after
validation.

If `/health` succeeds but `/advice` returns `502`, inspect only the recent agent errors:

```bash
kubectl logs \
  deployment/ai-agent \
  --namespace "$APP_NAMESPACE" \
  --tail=100
```

Check, in order:

1. Endpoint reachability and private networking.
2. Deployment name, model availability, quota, and content filters.
3. Service-account annotation and pod label.
4. Exact issuer and federated subject.
5. `Cognitive Services OpenAI User` assignment and propagation.

Do not solve an identity failure by adding an API key or broad `Contributor` role.

## Stage 4: Compare the implementations

Use this parity record:

| Dimension | Private K3s | AKS |
| --- | --- | --- |
| Application addition | `iac/ai.bicep` | `iac/ai.bicep` |
| Contract | `Radius.Resources/aiModels` | `Radius.Resources/aiModels` |
| Agent | Same published `ai-agent` image | Same published `ai-agent` image |
| Recipe output provider | `local` | `azure` |
| Model identifier | `qwen2.5:0.5b` | Existing deployment name |
| Backing host | Ollama Deployment and Service | Existing Azure OpenAI account |
| Credential | None for in-cluster endpoint | Federated managed identity |
| Compute/cost | Workshop VM CPU and download egress | Azure token usage and quota |
| Persistence | Model cache is ephemeral | Managed service deployment |
| Network dependency | Download required; inference then in-cluster | Endpoint required for every call |

The stable application contract does not promise equal model quality, latency,
throughput, context size, safety controls, or disconnected operation. Those are
capability-level service objectives owned by the platform and application teams
together.

The frontend can reach the newly created `ai-agent` service by its stable Radius
container name. Challenge 08 does not redeploy `iac/app.bicep`, so Challenge 06's
target-specific OIDC client secret and broker configuration are not overwritten.

## Optional cleanup

Cleanup is not required between challenges. If cost or policy requires it, remove only
the resources created here and select each target explicitly first.

For either active Radius target, remove the additive resources before unregistering the
recipe:

**Bash:**

```bash
rad resource delete Applications.Core/containers ai-agent \
  --application adaptive-apps \
  --workspace "<ws-local-prod-or-ws-azure-prod>" \
  --group rg-trading \
  --yes
rad resource delete Radius.Resources/aiModels trading-ai \
  --application adaptive-apps \
  --workspace "<ws-local-prod-or-ws-azure-prod>" \
  --group rg-trading \
  --yes
rad recipe unregister default \
  --workspace "<ws-local-prod-or-ws-azure-prod>" \
  --group rg-trading \
  --environment "<env-local-prod-or-env-azure-prod>" \
  --resource-type Radius.Resources/aiModels
kubectl delete namespace adaptive-recipes
```

**PowerShell 7:**

```powershell
rad resource delete Applications.Core/containers ai-agent `
    --application adaptive-apps `
    --workspace "<ws-local-prod-or-ws-azure-prod>" `
    --group rg-trading `
    --yes
rad resource delete Radius.Resources/aiModels trading-ai `
    --application adaptive-apps `
    --workspace "<ws-local-prod-or-ws-azure-prod>" `
    --group rg-trading `
    --yes
rad recipe unregister default `
    --workspace "<ws-local-prod-or-ws-azure-prod>" `
    --group rg-trading `
    --environment "<env-local-prod-or-env-azure-prod>" `
    --resource-type Radius.Resources/aiModels
kubectl delete namespace adaptive-recipes
```

On AKS, delete the dedicated identity only when no other workload uses it. Remove its
account-scoped role assignment first:

**Bash:**

```bash
az role assignment delete \
  --assignee-object-id "$AI_PRINCIPAL_ID" \
  --role "Cognitive Services OpenAI User" \
  --scope "$OPENAI_ID"
kubectl delete serviceaccount ai-agent --namespace "$APP_NAMESPACE"
az identity delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_IDENTITY_NAME"
```

**PowerShell 7:**

```powershell
az role assignment delete `
    --assignee-object-id $AiPrincipalId `
    --role "Cognitive Services OpenAI User" `
    --scope $OpenAiId
kubectl delete serviceaccount ai-agent --namespace $AppNamespace
az identity delete `
    --resource-group $env:RESOURCE_GROUP `
    --name $env:AI_IDENTITY_NAME
```

These commands do not delete the existing Azure OpenAI account or deployment. Their
owner retains responsibility for quota, capacity, model lifecycle, and cost.

## Optional GPU path

The source Kaito recipe is useful only on a target that actually has a supported GPU
node and the required drivers, device plugin, storage, and capacity. A production
platform team may publish that recipe under the same AI contract and select it through
an environment. Do not claim Kaito validation on `Standard_D4s_v5`, and document GPU VM
cost and regional capacity before provisioning an optional target.
