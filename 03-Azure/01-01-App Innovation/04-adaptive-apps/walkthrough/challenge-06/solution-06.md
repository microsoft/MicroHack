# Walkthrough Challenge 06 - Adapt Identity Services - Configure User Authentication

[< Previous Solution](../challenge-05/solution-05.md) - **[Home](../../Readme.md)** - [Next Challenge >](../../challenges/challenge-07.md)

Duration: 60-90 minutes

## Coach notes

This challenge is about **end-user authentication**. It does not replace the federated
identity Radius uses to deploy Azure resources, and it does not complete the workload
identity and authorization needed by Event Grid MQTT.

```text
Radius control-plane identity    Radius -> Azure Resource Manager
Application workload identity   pod -> platform service
End-user authentication         browser -> frontend -> Keycloak -> user authority
```

The authoritative Challenge 06 pattern is:

```text
K3s: browser -> frontend OIDC -> Keycloak -> local Keycloak user
AKS: browser -> frontend OIDC -> Keycloak -> Entra SAML -> Keycloak -> frontend
```

Keycloak is the protocol and portability boundary. The frontend always uses the same
confidential OIDC client, callback, and endpoint shape. The two Keycloak databases,
client secrets, user sources, and Radius application states remain independent.

The `core` portfolio from Challenge 03 already deployed `core-keycloak` in namespace
`core`. Do not instantiate the application-scoped `idProviders` recipe here: its
current workshop implementation assumes a separate ingress path, while this challenge
deliberately reuses the shared portfolio broker through foreground port-forwarding.

The local target uses a Keycloak-local test user because this MicroHack does not deploy
AD DS. If a site already has AD DS, the optional LDAPS extension at the end preserves
the source challenge's local-directory scenario.

## Fixed target map

| Platform | Kubernetes context | Radius workspace | Environment | Radius group |
| --- | --- | --- | --- | --- |
| Private K3s through Bastion | `k3s-azure-vm` | `ws-local-prod` | `env-local-prod` | `rg-trading` |
| AKS | `aks-adaptive-apps` | `ws-azure-prod` | `env-azure-prod` | `rg-trading` |

Before every stage, select and verify Kubernetes context, Radius workspace, group, and
environment. Keycloak follows the Kubernetes context; the application deployment
follows the Radius workspace.

## Stage 1: Understand the stable application contract

Challenge 06 extends `iac/app.bicep` once with optional parameters:

| Parameter | Ownership | Purpose |
| --- | --- | --- |
| `oidcClientId` | Application contract | Stable client ID `adaptive-apps` |
| `oidcClientSecret` | Broker instance | Target-specific confidential-client secret |
| `oidcIssuer` | Environment | Internal Keycloak realm URL |
| `oidcAuthEndpoint` | Environment | Internal authorization endpoint |
| `oidcBrowserAuthEndpoint` | Workshop access | Browser-reachable localhost endpoint |
| `oidcTokenEndpoint` | Environment | Internal token endpoint |
| `oidcUserInfoEndpoint` | Environment | Internal user-info endpoint |
| `appBaseUrl` | Application exposure | Builds the callback URL |

All OIDC parameters default to empty except `appBaseUrl`. Omitting them preserves
Challenge 05 behavior. Enabling them adds these frontend variables without introducing
Entra or K3s resource declarations into the model:

```text
OIDC_CLIENT_ID
OIDC_CLIENT_SECRET
OIDC_ISSUER
OIDC_AUTH_ENDPOINT
OIDC_BROWSER_AUTH_ENDPOINT
OIDC_TOKEN_ENDPOINT
OIDC_USERINFO_ENDPOINT
APP_BASE_URL
```

For this workshop:

```text
Internal realm: http://core-keycloak.core.svc.cluster.local:8080/realms/master
Browser auth:   http://localhost:8080/realms/master/protocol/openid-connect/auth
Callback:       http://localhost:3000/auth/oidc/callback
```

The split endpoints matter. The participant browser cannot resolve a cluster-local
service name, and the frontend pod cannot reach the devcontainer's localhost.

## Stage 2: Configure the private K3s identity path

### 1. Restore and verify the K3s target

The kubeconfig endpoint is localhost because `prepare-k3s-azure-vm.sh connect` maintains
an Azure Bastion native-client tunnel to the private VM's Kubernetes API.

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
kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
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
kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
```

### 2. Reconcile the confidential OIDC client

Use Keycloak's administration CLI inside the pod. The bootstrap administrator password
is consumed inside the container and never crosses the Kubernetes API or terminal.

**Bash:**

```bash
KEYCLOAK_POD="$(
  kubectl get pods --namespace core \
    --selector app.kubernetes.io/component=keycloak \
    --field-selector status.phase=Running \
    --output jsonpath='{.items[0].metadata.name}'
)"
test -n "$KEYCLOAK_POD"

kubectl exec --namespace core "$KEYCLOAK_POD" -- /bin/sh -c \
  '/opt/keycloak/bin/kcadm.sh config credentials \
    --config /tmp/kcadm.config \
    --server http://127.0.0.1:8080 \
    --realm master \
    --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
    --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"'

CLIENT_SPEC="$(
  jq -n '{
    clientId: "adaptive-apps",
    name: "Adaptive Apps frontend",
    enabled: true,
    protocol: "openid-connect",
    publicClient: false,
    clientAuthenticatorType: "client-secret",
    standardFlowEnabled: true,
    implicitFlowEnabled: false,
    directAccessGrantsEnabled: false,
    serviceAccountsEnabled: false,
    redirectUris: ["http://localhost:3000/*"],
    webOrigins: ["http://localhost:3000"]
  }'
)"

CLIENT_UUID="$(
  kubectl exec --namespace core "$KEYCLOAK_POD" -- \
    /opt/keycloak/bin/kcadm.sh get clients \
      --config /tmp/kcadm.config \
      --realm master \
      --query clientId=adaptive-apps |
    jq -r '.[] | select(.clientId == "adaptive-apps") | .id' |
    head -n 1
)"

if [ -z "$CLIENT_UUID" ]; then
  printf '%s' "$CLIENT_SPEC" |
    kubectl exec --stdin --namespace core "$KEYCLOAK_POD" -- \
      /opt/keycloak/bin/kcadm.sh create clients \
        --config /tmp/kcadm.config \
        --realm master \
        --file -
  CLIENT_UUID="$(
    kubectl exec --namespace core "$KEYCLOAK_POD" -- \
      /opt/keycloak/bin/kcadm.sh get clients \
        --config /tmp/kcadm.config \
        --realm master \
        --query clientId=adaptive-apps |
      jq -r '.[] | select(.clientId == "adaptive-apps") | .id' |
      head -n 1
  )"
else
  printf '%s' "$CLIENT_SPEC" |
    kubectl exec --stdin --namespace core "$KEYCLOAK_POD" -- \
      /opt/keycloak/bin/kcadm.sh update "clients/$CLIENT_UUID" \
        --config /tmp/kcadm.config \
        --realm master \
        --file -
fi

test -n "$CLIENT_UUID"
OIDC_CLIENT_SECRET="$(
  kubectl exec --namespace core "$KEYCLOAK_POD" -- \
    /opt/keycloak/bin/kcadm.sh get "clients/$CLIENT_UUID/client-secret" \
      --config /tmp/kcadm.config \
      --realm master |
    jq -er '.value'
)"
test -n "$OIDC_CLIENT_SECRET"
unset CLIENT_SPEC
```

**PowerShell 7:**

```powershell
$KeycloakPod = kubectl get pods --namespace core `
    --selector app.kubernetes.io/component=keycloak `
    --field-selector status.phase=Running `
    --output jsonpath='{.items[0].metadata.name}'
if ([string]::IsNullOrWhiteSpace($KeycloakPod)) {
    throw "No running Keycloak pod found in namespace core."
}

kubectl exec --namespace core $KeycloakPod -- /bin/sh -c `
    '/opt/keycloak/bin/kcadm.sh config credentials --config /tmp/kcadm.config --server http://127.0.0.1:8080 --realm master --user "$KC_BOOTSTRAP_ADMIN_USERNAME" --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"'
if ($LASTEXITCODE -ne 0) {
    throw "Keycloak admin authentication failed."
}

$ClientSpec = @{
    clientId = "adaptive-apps"
    name = "Adaptive Apps frontend"
    enabled = $true
    protocol = "openid-connect"
    publicClient = $false
    clientAuthenticatorType = "client-secret"
    standardFlowEnabled = $true
    implicitFlowEnabled = $false
    directAccessGrantsEnabled = $false
    serviceAccountsEnabled = $false
    redirectUris = @("http://localhost:3000/*")
    webOrigins = @("http://localhost:3000")
} | ConvertTo-Json -Compress

$Clients = kubectl exec --namespace core $KeycloakPod -- `
    /opt/keycloak/bin/kcadm.sh get clients `
    --config /tmp/kcadm.config `
    --realm master `
    --query clientId=adaptive-apps | ConvertFrom-Json
$ClientUuid = @($Clients | Where-Object clientId -eq "adaptive-apps")[0].id

if ([string]::IsNullOrWhiteSpace($ClientUuid)) {
    $ClientSpec | kubectl exec --stdin --namespace core $KeycloakPod -- `
        /opt/keycloak/bin/kcadm.sh create clients `
        --config /tmp/kcadm.config `
        --realm master `
        --file -
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create the Keycloak client."
    }
    $Clients = kubectl exec --namespace core $KeycloakPod -- `
        /opt/keycloak/bin/kcadm.sh get clients `
        --config /tmp/kcadm.config `
        --realm master `
        --query clientId=adaptive-apps | ConvertFrom-Json
    $ClientUuid = @($Clients | Where-Object clientId -eq "adaptive-apps")[0].id
}
else {
    $ClientSpec | kubectl exec --stdin --namespace core $KeycloakPod -- `
        /opt/keycloak/bin/kcadm.sh update "clients/$ClientUuid" `
        --config /tmp/kcadm.config `
        --realm master `
        --file -
    if ($LASTEXITCODE -ne 0) {
        throw "Could not update the Keycloak client."
    }
}

if ([string]::IsNullOrWhiteSpace($ClientUuid)) {
    throw "Keycloak did not return an adaptive-apps client ID."
}
$OidcClientSecret = (
    kubectl exec --namespace core $KeycloakPod -- `
        /opt/keycloak/bin/kcadm.sh get "clients/$ClientUuid/client-secret" `
        --config /tmp/kcadm.config `
        --realm master |
    ConvertFrom-Json
).value
if ([string]::IsNullOrWhiteSpace($OidcClientSecret)) {
    throw "Keycloak did not return a client secret."
}
$ClientSpec = $null
```

The client secret is held only in memory. Do not run a command that writes it to the
terminal, shell profile, transcript, or parameters file.

### 3. Create a local application user

The application user must not be the Keycloak administrator.

**Bash:**

```bash
LOCAL_USERNAME="local-trader"

LOCAL_USER_ID="$(
  kubectl exec --namespace core "$KEYCLOAK_POD" -- \
    /opt/keycloak/bin/kcadm.sh get users \
      --config /tmp/kcadm.config \
      --realm master \
      --query "username=$LOCAL_USERNAME" |
    jq -r --arg username "$LOCAL_USERNAME" \
      '.[] | select(.username == $username) | .id' |
    head -n 1
)"

if [ -z "$LOCAL_USER_ID" ]; then
  kubectl exec --namespace core "$KEYCLOAK_POD" -- \
    /opt/keycloak/bin/kcadm.sh create users \
      --config /tmp/kcadm.config \
      --realm master \
      --set "username=$LOCAL_USERNAME" \
      --set enabled=true
fi

read -rsp "Password for $LOCAL_USERNAME: " LOCAL_USER_PASSWORD
echo
if ! printf '%s\n%s\n' "$LOCAL_USERNAME" "$LOCAL_USER_PASSWORD" |
  kubectl exec --stdin --namespace core "$KEYCLOAK_POD" -- /bin/sh -c \
    'IFS= read -r USERNAME
     IFS= read -r PASSWORD
     exec /opt/keycloak/bin/kcadm.sh set-password \
       --config /tmp/kcadm.config \
       --realm master \
       --username "$USERNAME" \
       --new-password "$PASSWORD" \
       --temporary=false'; then
  echo "Local user password update failed. Resolve the error before continuing." >&2
fi
unset LOCAL_USER_PASSWORD LOCAL_USER_ID
```

**PowerShell 7:**

```powershell
$LocalUsername = "local-trader"
$LocalUsers = kubectl exec --namespace core $KeycloakPod -- `
    /opt/keycloak/bin/kcadm.sh get users `
    --config /tmp/kcadm.config `
    --realm master `
    --query "username=$LocalUsername" | ConvertFrom-Json
$LocalUser = @($LocalUsers | Where-Object username -eq $LocalUsername)[0]

if ($null -eq $LocalUser) {
    kubectl exec --namespace core $KeycloakPod -- `
        /opt/keycloak/bin/kcadm.sh create users `
        --config /tmp/kcadm.config `
        --realm master `
        --set "username=$LocalUsername" `
        --set enabled=true
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create the local Keycloak user."
    }
}

$SecureLocalPassword = Read-Host "Password for $LocalUsername" -AsSecureString
$LocalCredential = [System.Management.Automation.PSCredential]::new(
    $LocalUsername,
    $SecureLocalPassword
)
$PlainLocalPassword = $LocalCredential.GetNetworkCredential().Password
try {
    "$LocalUsername`n$PlainLocalPassword`n" |
        kubectl exec --stdin --namespace core $KeycloakPod -- /bin/sh -c `
        'IFS= read -r USERNAME; IFS= read -r PASSWORD; exec /opt/keycloak/bin/kcadm.sh set-password --config /tmp/kcadm.config --realm master --username "$USERNAME" --new-password "$PASSWORD" --temporary=false'
    if ($LASTEXITCODE -ne 0) {
        throw "Could not set the local Keycloak user password."
    }
}
finally {
    $PlainLocalPassword = $null
    $LocalCredential = $null
    $SecureLocalPassword = $null
}
```

The password travels over `kubectl exec` standard input and becomes a `kcadm.sh`
argument only inside the pod. It is not placed in the Kubernetes API request URL or the
local process argument list. Use a trusted workshop workstation, keep terminal
transcription disabled, and clear the variable immediately.

### 4. Rotate the workshop broker administrator

The portfolio bootstrap credential initializes Keycloak but is not suitable for ongoing
administration. Rotate it before exposing the broker to the browser. This target-neutral
block changes the database password and updates the Helm-managed Kubernetes Secret
without placing the password in an API URL or local process argument list.

**Bash:**

```bash
KEYCLOAK_ADMIN_USERNAME="$(
  kubectl get secret core-keycloak-admin --namespace core \
    --output jsonpath='{.data.username}' |
  base64 --decode
)"
test -n "$KEYCLOAK_ADMIN_USERNAME"

read -rsp "New workshop Keycloak admin password: " KEYCLOAK_ADMIN_PASSWORD
echo
if printf '%s\n%s\n' "$KEYCLOAK_ADMIN_USERNAME" "$KEYCLOAK_ADMIN_PASSWORD" |
  kubectl exec --stdin --namespace core "$KEYCLOAK_POD" -- /bin/sh -c \
    'IFS= read -r USERNAME
     IFS= read -r PASSWORD
     exec /opt/keycloak/bin/kcadm.sh set-password \
       --config /tmp/kcadm.config \
       --realm master \
       --username "$USERNAME" \
       --new-password "$PASSWORD" \
       --temporary=false'; then
  export KEYCLOAK_ADMIN_USERNAME KEYCLOAK_ADMIN_PASSWORD
  ADMIN_SECRET_MANIFEST="$(
    jq -n '{
        apiVersion: "v1",
        kind: "Secret",
        metadata: {
          name: "core-keycloak-admin",
          namespace: "core"
        },
        type: "Opaque",
        stringData: {
          username: env.KEYCLOAK_ADMIN_USERNAME,
          password: env.KEYCLOAK_ADMIN_PASSWORD
        }
      }'
  )"
  export -n KEYCLOAK_ADMIN_USERNAME KEYCLOAK_ADMIN_PASSWORD
  if printf '%s' "$ADMIN_SECRET_MANIFEST" | kubectl apply --filename -; then
    unset ADMIN_SECRET_MANIFEST KEYCLOAK_ADMIN_PASSWORD
    kubectl rollout restart deployment/core-keycloak --namespace core
    kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
    unset KEYCLOAK_POD
  else
    unset ADMIN_SECRET_MANIFEST
    echo "Secret update failed. Do not restart Keycloak." >&2
    echo "Retry the Secret update while KEYCLOAK_ADMIN_PASSWORD remains available." >&2
  fi
else
  unset KEYCLOAK_ADMIN_PASSWORD
  echo "Password change failed. The Secret was not updated; do not restart Keycloak." >&2
fi
```

**PowerShell 7:**

```powershell
$KeycloakAdminUsername = kubectl get secret core-keycloak-admin `
    --namespace core `
    --output jsonpath='{.data.username}'
$KeycloakAdminUsername = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($KeycloakAdminUsername)
)
if ([string]::IsNullOrWhiteSpace($KeycloakAdminUsername)) {
    throw "The Keycloak administrator username is missing."
}

$SecureAdminPassword = Read-Host "New workshop Keycloak admin password" -AsSecureString
$AdminCredential = [System.Management.Automation.PSCredential]::new(
    $KeycloakAdminUsername,
    $SecureAdminPassword
)
$PlainAdminPassword = $AdminCredential.GetNetworkCredential().Password
try {
    "$KeycloakAdminUsername`n$PlainAdminPassword`n" |
        kubectl exec --stdin --namespace core $KeycloakPod -- /bin/sh -c `
        'IFS= read -r USERNAME; IFS= read -r PASSWORD; exec /opt/keycloak/bin/kcadm.sh set-password --config /tmp/kcadm.config --realm master --username "$USERNAME" --new-password "$PASSWORD" --temporary=false'
    if ($LASTEXITCODE -ne 0) {
        throw "Could not rotate the Keycloak administrator password."
    }

    $AdminSecretManifest = @{
        apiVersion = "v1"
        kind = "Secret"
        metadata = @{
            name = "core-keycloak-admin"
            namespace = "core"
        }
        type = "Opaque"
        stringData = @{
            username = $KeycloakAdminUsername
            password = $PlainAdminPassword
        }
    } | ConvertTo-Json -Compress
    $AdminSecretManifest | kubectl apply --filename -
    if ($LASTEXITCODE -ne 0) {
        throw "The database password changed but the Secret update failed. Do not restart Keycloak; retry the Secret apply with the chosen password."
    }
}
finally {
    $AdminSecretManifest = $null
    $PlainAdminPassword = $null
    $AdminCredential = $null
    $SecureAdminPassword = $null
}

kubectl rollout restart deployment/core-keycloak --namespace core
kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
$KeycloakPod = $null
```

Keep the chosen password in the participant's approved password manager. The rollout
invalidates the previous pod name and `/tmp/kcadm.config`; repeat the pod-discovery and
`kcadm.sh config credentials` block from step 2 before any later admin CLI operation.
Do not use the administrator account for application sign-in.

### 5. Redeploy the application with OIDC enabled

The Keycloak client secret and frontend break-glass password are separate. Retain a
strong local frontend password for the workshop, but validate the OIDC path.

**Bash:**

```bash
OIDC_ISSUER="http://core-keycloak.core.svc.cluster.local:8080/realms/master"
OIDC_AUTH_ENDPOINT="$OIDC_ISSUER/protocol/openid-connect/auth"
OIDC_TOKEN_ENDPOINT="$OIDC_ISSUER/protocol/openid-connect/token"
OIDC_USERINFO_ENDPOINT="$OIDC_ISSUER/protocol/openid-connect/userinfo"
OIDC_BROWSER_AUTH_ENDPOINT="http://localhost:8080/realms/master/protocol/openid-connect/auth"

read -rsp "Frontend break-glass password: " AUTH_PASSWORD
echo
rad deploy iac/app.bicep \
  --workspace ws-local-prod \
  --group rg-trading \
  --environment env-local-prod \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest \
  --parameters authUsername=admin \
  --parameters "authPassword=$AUTH_PASSWORD" \
  --parameters oidcClientId=adaptive-apps \
  --parameters "oidcClientSecret=$OIDC_CLIENT_SECRET" \
  --parameters "oidcIssuer=$OIDC_ISSUER" \
  --parameters "oidcAuthEndpoint=$OIDC_AUTH_ENDPOINT" \
  --parameters "oidcBrowserAuthEndpoint=$OIDC_BROWSER_AUTH_ENDPOINT" \
  --parameters "oidcTokenEndpoint=$OIDC_TOKEN_ENDPOINT" \
  --parameters "oidcUserInfoEndpoint=$OIDC_USERINFO_ENDPOINT" \
  --parameters appBaseUrl=http://localhost:3000
unset AUTH_PASSWORD OIDC_CLIENT_SECRET
```

**PowerShell 7:**

```powershell
$OidcIssuer = "http://core-keycloak.core.svc.cluster.local:8080/realms/master"
$OidcAuthEndpoint = "$OidcIssuer/protocol/openid-connect/auth"
$OidcTokenEndpoint = "$OidcIssuer/protocol/openid-connect/token"
$OidcUserInfoEndpoint = "$OidcIssuer/protocol/openid-connect/userinfo"
$OidcBrowserAuthEndpoint = "http://localhost:8080/realms/master/protocol/openid-connect/auth"

$SecurePassword = Read-Host "Frontend break-glass password" -AsSecureString
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
        --parameters "authPassword=$PlainPassword" `
        --parameters oidcClientId=adaptive-apps `
        --parameters "oidcClientSecret=$OidcClientSecret" `
        --parameters "oidcIssuer=$OidcIssuer" `
        --parameters "oidcAuthEndpoint=$OidcAuthEndpoint" `
        --parameters "oidcBrowserAuthEndpoint=$OidcBrowserAuthEndpoint" `
        --parameters "oidcTokenEndpoint=$OidcTokenEndpoint" `
        --parameters "oidcUserInfoEndpoint=$OidcUserInfoEndpoint" `
        --parameters appBaseUrl=http://localhost:3000
}
finally {
    $PlainPassword = $null
    $Credential = $null
    $SecurePassword = $null
    $OidcClientSecret = $null
}
```

### 6. Validate K3s without disclosing secret values

The frontend image logs whether OIDC is enabled without logging its client secret. Use
that startup diagnostic rather than rendering the container resource or Deployment:
the current Radius container contract stores the client secret as an inline environment
value, so `rad resource show` and `kubectl get deployment -o yaml` are not safe evidence.

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
kubectl rollout status deployment/frontend \
  --namespace "$APP_NAMESPACE" \
  --timeout=5m

FRONTEND_POD="$(
  kubectl get pods --namespace "$APP_NAMESPACE" --output json |
    jq -r '
      .items |
      map(select(
        .status.phase == "Running" and
        any(.spec.containers[]; .name == "frontend")
      )) |
      sort_by(.metadata.creationTimestamp) |
      last |
      .metadata.name // empty
    '
)"
test -n "$FRONTEND_POD"
kubectl logs "$FRONTEND_POD" \
  --namespace "$APP_NAMESPACE" \
  --container frontend |
  grep -E "OIDC auth[[:space:]]*:[[:space:]]*enabled" >/dev/null
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
kubectl rollout status deployment/frontend `
    --namespace $AppNamespace `
    --timeout=5m

$Pods = kubectl get pods --namespace $AppNamespace --output json |
    ConvertFrom-Json
$FrontendPod = @(
    $Pods.items |
        Where-Object {
            $_.status.phase -eq "Running" -and
            "frontend" -in $_.spec.containers.name
        } |
        Sort-Object { [datetime]$_.metadata.creationTimestamp } -Descending
)[0].metadata.name
if ([string]::IsNullOrWhiteSpace($FrontendPod)) {
    throw "No frontend pod found."
}
$FrontendLogs = kubectl logs $FrontendPod `
    --namespace $AppNamespace `
    --container frontend
if (-not ($FrontendLogs -match "OIDC auth\s*:\s*enabled")) {
    throw "The frontend did not report OIDC as enabled."
}
```

### 7. Validate local-user sign-in

Use two foreground terminals. Keep the Bastion tunnel process managed by
`prepare-k3s-azure-vm.sh`; these commands add only Kubernetes/Radius port-forwards.

**Terminal A - Bash:**

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl port-forward --namespace core service/core-keycloak 8080:8080
```

**Terminal A - PowerShell 7:**

```powershell
$env:KUBECONFIG = "$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl port-forward --namespace core service/core-keycloak 8080:8080
```

**Terminal B - Bash:**

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps \
  --port 3000 \
  --remote-port 3000
```

**Terminal B - PowerShell 7:**

```powershell
$env:KUBECONFIG = "$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
rad workspace switch ws-local-prod
rad group switch rg-trading
rad env switch env-local-prod
rad resource expose Applications.Core/containers frontend `
    --application adaptive-apps `
    --port 3000 `
    --remote-port 3000
```

Open <http://localhost:3000>, choose the OIDC sign-in path, and authenticate as
`local-trader`. The browser visits Keycloak on <http://localhost:8080>; the frontend
exchanges the authorization code through `core-keycloak.core.svc.cluster.local`.

Successful evidence is the authenticated frontend identity, not a screenshot containing
cookies, tokens, passwords, or client secrets.

Press <kbd>Ctrl</kbd>+<kbd>C</kbd> in both terminals before continuing.

## Stage 3: Configure Entra federation on AKS

### 1. Stop K3s forwarding and verify the AKS target

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
kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
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
kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
```

### 2. Create the same OIDC client on AKS

Repeat **Stage 2, step 2** now that the active context is `aks-adaptive-apps`. Do not
reuse the K3s `KEYCLOAK_POD`, `$KeycloakPod`, `CLIENT_UUID`, `$ClientUuid`, or client
secret. The commands reconcile an `adaptive-apps` client with the same settings in the
independent AKS Keycloak database and capture a new secret in:

- Bash: `OIDC_CLIENT_SECRET`
- PowerShell: `$OidcClientSecret`

Before proceeding, verify non-secret settings only:

**Bash:**

```bash
kubectl exec --namespace core "$KEYCLOAK_POD" -- \
  /opt/keycloak/bin/kcadm.sh get "clients/$CLIENT_UUID" \
    --config /tmp/kcadm.config \
    --realm master |
  jq '{
    clientId,
    enabled,
    publicClient,
    standardFlowEnabled,
    redirectUris,
    webOrigins
  }'
```

**PowerShell 7:**

```powershell
$Client = kubectl exec --namespace core $KeycloakPod -- `
    /opt/keycloak/bin/kcadm.sh get "clients/$ClientUuid" `
    --config /tmp/kcadm.config `
    --realm master | ConvertFrom-Json
$Client | Select-Object `
    clientId, enabled, publicClient, standardFlowEnabled, redirectUris, webOrigins
```

Expected: `adaptive-apps`, enabled, confidential (`publicClient: false`), standard flow
enabled, redirect URI `http://localhost:3000/*`, and web origin
`http://localhost:3000`.

### 3. Rotate the AKS broker administrator

Repeat **Stage 2, step 4** while the AKS context is active. Use a different approved
password from the K3s broker. The block restarts Keycloak and deliberately clears the
now-stale pod variable; no later step depends on the old admin CLI session.

### 4. Configure Entra as an upstream SAML provider

Start the AKS Keycloak forward in a foreground terminal:

**Bash or PowerShell 7:**

```text
kubectl port-forward --namespace core service/core-keycloak 8080:8080
```

Open the [Keycloak admin console](http://localhost:8080/admin/master/console/) and sign
in with the administrator username and the password chosen in the previous step.

In the [Microsoft Entra admin center](https://entra.microsoft.com):

1. Go to **Entra ID** > **Enterprise applications** > **New application** >
   **Create your own application**.
2. Name it `Adaptive Apps Keycloak workshop` and choose the non-gallery option that
   integrates another application.
3. Under **Single sign-on**, select **SAML**.
4. Choose a short team identifier that is unique within the shared Entra tenant, such
   as `team-07`. Configure **Basic SAML Configuration**, replacing `<team-id>`:

   | Setting | Workshop value |
   | --- | --- |
   | Identifier (Entity ID) | `urn:adaptive-apps:keycloak:<team-id>` |
   | Reply URL (ACS) | `http://localhost:8080/realms/master/broker/entra/endpoint` |

5. Keep the minimum default claims required for sign-in. Ensure the Name ID identifies
   the assigned user and that email, given name, and surname claims are available when
   your tenant policy permits them.
6. Under **Users and groups**, assign only the workshop test user or a narrowly scoped
   workshop group. Do not disable assignment merely to make the demo pass.
7. Download **Federation Metadata XML** from **SAML Certificates**. Treat certificates
   and metadata as configuration; never download browser session data or tokens.

In the Keycloak admin console:

1. Select realm **master**.
2. Open **Identity providers** and choose **SAML v2.0**.
3. Set alias `entra` and display name `Microsoft Entra ID`.
4. Import the downloaded Entra Federation Metadata XML.
5. Confirm the provider is enabled, the single sign-on service URL targets the intended
   tenant, signature validation is enabled, and sync mode is `FORCE` for this workshop
   so mapping changes are visible at the next login.
6. Set **Service provider entity ID** to the same
   `urn:adaptive-apps:keycloak:<team-id>` value registered in Entra.
7. Save, open **Mappers**, and add these **Attribute Importer** mappings with
   **Name Format** `ATTRIBUTE_FORMAT_BASIC` and sync mode `INHERIT`:

   | Name | SAML attribute name | Keycloak user attribute |
   | --- | --- | --- |
   | `email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` | `email` |
   | `firstName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname` | `firstName` |
   | `lastName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname` | `lastName` |

The Keycloak login page should now show **Microsoft Entra ID**. The frontend still uses
OIDC only; Keycloak performs the SAML protocol bridge.

> [!IMPORTANT]
> The localhost entity ID and reply URL are for this foreground, port-forwarded lab.
> Production requires a stable HTTPS Keycloak hostname, a matching SAML entity ID and
> reply URL, managed certificates, restricted origins/redirects, durable secret
> rotation, and an availability plan.

### 5. Deploy the same model to the Azure environment

Use the AKS client secret captured in Stage 3, step 2. The endpoint values match K3s
because both portfolios use the same service and realm names; the secret and upstream
provider differ.

**Bash:**

```bash
OIDC_ISSUER="http://core-keycloak.core.svc.cluster.local:8080/realms/master"
OIDC_AUTH_ENDPOINT="$OIDC_ISSUER/protocol/openid-connect/auth"
OIDC_TOKEN_ENDPOINT="$OIDC_ISSUER/protocol/openid-connect/token"
OIDC_USERINFO_ENDPOINT="$OIDC_ISSUER/protocol/openid-connect/userinfo"
OIDC_BROWSER_AUTH_ENDPOINT="http://localhost:8080/realms/master/protocol/openid-connect/auth"

read -rsp "Frontend break-glass password: " AUTH_PASSWORD
echo
rad deploy iac/app.bicep \
  --workspace ws-azure-prod \
  --group rg-trading \
  --environment env-azure-prod \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest \
  --parameters authUsername=admin \
  --parameters "authPassword=$AUTH_PASSWORD" \
  --parameters oidcClientId=adaptive-apps \
  --parameters "oidcClientSecret=$OIDC_CLIENT_SECRET" \
  --parameters "oidcIssuer=$OIDC_ISSUER" \
  --parameters "oidcAuthEndpoint=$OIDC_AUTH_ENDPOINT" \
  --parameters "oidcBrowserAuthEndpoint=$OIDC_BROWSER_AUTH_ENDPOINT" \
  --parameters "oidcTokenEndpoint=$OIDC_TOKEN_ENDPOINT" \
  --parameters "oidcUserInfoEndpoint=$OIDC_USERINFO_ENDPOINT" \
  --parameters appBaseUrl=http://localhost:3000
unset AUTH_PASSWORD OIDC_CLIENT_SECRET
```

**PowerShell 7:**

```powershell
$OidcIssuer = "http://core-keycloak.core.svc.cluster.local:8080/realms/master"
$OidcAuthEndpoint = "$OidcIssuer/protocol/openid-connect/auth"
$OidcTokenEndpoint = "$OidcIssuer/protocol/openid-connect/token"
$OidcUserInfoEndpoint = "$OidcIssuer/protocol/openid-connect/userinfo"
$OidcBrowserAuthEndpoint = "http://localhost:8080/realms/master/protocol/openid-connect/auth"

$SecurePassword = Read-Host "Frontend break-glass password" -AsSecureString
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
        --parameters "authPassword=$PlainPassword" `
        --parameters oidcClientId=adaptive-apps `
        --parameters "oidcClientSecret=$OidcClientSecret" `
        --parameters "oidcIssuer=$OidcIssuer" `
        --parameters "oidcAuthEndpoint=$OidcAuthEndpoint" `
        --parameters "oidcBrowserAuthEndpoint=$OidcBrowserAuthEndpoint" `
        --parameters "oidcTokenEndpoint=$OidcTokenEndpoint" `
        --parameters "oidcUserInfoEndpoint=$OidcUserInfoEndpoint" `
        --parameters appBaseUrl=http://localhost:3000
}
finally {
    $PlainPassword = $null
    $Credential = $null
    $SecurePassword = $null
    $OidcClientSecret = $null
}
```

### 6. Validate Entra-backed sign-in

Keep the Keycloak forward running on port 8080. In a second foreground terminal:

**Bash:**

```bash
unset KUBECONFIG
kubectl config use-context aks-adaptive-apps
rad workspace switch ws-azure-prod
rad group switch rg-trading
rad env switch env-azure-prod

rad app graph --application adaptive-apps
rad resource list --application adaptive-apps
rad resource expose Applications.Core/containers frontend \
  --application adaptive-apps \
  --port 3000 \
  --remote-port 3000
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
rad resource expose Applications.Core/containers frontend `
    --application adaptive-apps `
    --port 3000 `
    --remote-port 3000
```

Open a private browser window at <http://localhost:3000>, choose OIDC sign-in, select
**Microsoft Entra ID** at Keycloak, and authenticate as an assigned Entra user. A private
window prevents the earlier K3s Keycloak cookie from masquerading as AKS evidence.

The expected sequence is:

```text
frontend -> localhost Keycloak authorization endpoint
         -> Entra SAML sign-in
         -> localhost Keycloak broker endpoint
         -> frontend callback on localhost:3000
```

Stop both foreground processes when validation completes.

## Stage 4: Compare and debrief

| Area | K3s / `ws-local-prod` | AKS / `ws-azure-prod` |
| --- | --- | --- |
| App model | `iac/app.bicep` | `iac/app.bicep` |
| App-facing protocol | OIDC | OIDC |
| Client ID | `adaptive-apps` | `adaptive-apps` |
| Redirect URI | `http://localhost:3000/*` | `http://localhost:3000/*` |
| Broker | `core-keycloak` | `core-keycloak` |
| Client secret | K3s-specific | AKS-specific |
| User authority | Local Keycloak user | Microsoft Entra ID |
| Upstream protocol | Keycloak local authentication | SAML |
| Browser access | Local 8080 and 3000 forwards over Bastion-backed API access | Local 8080 and 3000 forwards to AKS |
| Radius state | Independent | Independent |

The application team owns the OIDC client contract and callback behavior. The platform
team owns Keycloak availability, upstream federation, certificates, client-secret
rotation, user/group mapping, and production ingress. The identity team owns Entra app
policy, assignments, claims, conditional access, and lifecycle.

### What did not change

- Application Bicep resource graph
- Frontend image
- OIDC client ID and authorization-code flow
- Redirect URI and local browser ports
- Radius resource contracts

### What changed by environment

- Active Kubernetes context and Radius workspace/environment
- Keycloak database and client secret
- User authority and upstream protocol
- Broker-side provider and user configuration

## Troubleshooting

### K3s reports connection refused on `127.0.0.1:16443`

The devcontainer restarted and the Bastion process is no longer running:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
```

In PowerShell, set `$env:AZURE_SUBSCRIPTION`, invoke the same script through `bash`,
and set `$env:KUBECONFIG`.

### Local port 8080 or 3000 is already in use

Stop the stale foreground `kubectl port-forward` or `rad resource expose` process with
<kbd>Ctrl</kbd>+<kbd>C</kbd>. Do not kill processes by name. Confirm the intended
Kubernetes context and Radius workspace before starting a replacement.

### The frontend shows no OIDC sign-in option

Check that `rad deploy` received a non-empty client ID and secret. Inspect only
environment-variable names with a JSONPath that cannot render their values. Review
frontend pod logs for the non-secret `OIDC disabled: missing config` diagnostic; never
dump all environment values.

**Bash:**

```bash
kubectl get deployment frontend \
  --namespace "$APP_NAMESPACE" \
  --output jsonpath='{.spec.template.spec.containers[?(@.name=="frontend")].env[*].name}'
echo
```

**PowerShell 7:**

```powershell
kubectl get deployment frontend `
    --namespace $AppNamespace `
    --output jsonpath='{.spec.template.spec.containers[?(@.name=="frontend")].env[*].name}'
Write-Output ""
```

### Keycloak reports an invalid redirect URI

The client must include `http://localhost:3000/*`, while `appBaseUrl` must be
`http://localhost:3000`. Keep the callback generated by the frontend at
`/auth/oidc/callback`.

### The browser cannot reach the authorization endpoint

The browser endpoint must use `http://localhost:8080`. Cluster-local
`core-keycloak.core.svc.cluster.local` addresses are only for frontend-to-Keycloak
token and user-info calls.

### Login succeeds at Keycloak but the callback fails

Check:

1. Keycloak client secret matches the active control plane.
2. Internal issuer, token, and user-info endpoints use the `core-keycloak` service.
3. Frontend and Keycloak forwards belong to the same cluster stage.
4. The frontend callback is on the current port-3000 exposure.

Do not copy the other cluster's client secret as a shortcut.

### Entra authenticates the user but denies application access

Check the enterprise application's **Users and groups** assignments and
**Assignment required** setting. Assign the intended test identity; do not disable
assignment globally just to pass the workshop.

### Keycloak does not show the Entra option

Verify the SAML provider is enabled, has alias `entra`, and imported metadata from the
intended tenant. Check that the Keycloak forward is still attached to
`aks-adaptive-apps`, not K3s.

### Entra reports a reply URL mismatch

For this lab the reply URL is exactly:

```text
http://localhost:8080/realms/master/broker/entra/endpoint
```

The alias is part of the URL. A production HTTPS hostname requires corresponding changes
in Entra, Keycloak, the OIDC browser endpoint, redirect origins, and application base
URL.

### Entra reports that the identifier is already in use

Another workshop application in the tenant already owns the SAML entity ID. Choose a
different `<team-id>`, then update both the Entra **Identifier (Entity ID)** and
Keycloak **Service provider entity ID** to the same unique
`urn:adaptive-apps:keycloak:<team-id>` value.

### The callback fails intermittently with an invalid authorization code

The portfolio runs multiple Keycloak replicas. Check both Keycloak pod logs for a
healthy Infinispan/JGroups cluster view. The browser forward can stay pinned to one pod
while the frontend token request reaches another through `core-keycloak`; a broken
Keycloak cache cluster makes authorization codes appear invalid on alternate requests.
Repair Keycloak clustering rather than weakening OIDC validation.

### A later portfolio upgrade breaks admin CLI authentication

`core-keycloak-admin` is managed by Helm. Re-running the Challenge 03
`helm upgrade --install core` command with the original chart values can restore the
old Kubernetes Secret while the Keycloak database retains the rotated password. Repeat
the target-specific administrator rotation with approved values after a portfolio
upgrade; do not print or recover the old password from command output.

### Do not use token output as evidence

Tokens, authorization codes, cookies, client secrets, and passwords are credentials.
Validate user identity in the frontend and use non-secret configuration metadata. Do
not paste tokens into JWT inspection sites or workshop notes.

## Optional enterprise local-directory extension

If a local AD DS deployment already exists, Keycloak can replace the local workshop
user source with LDAP federation:

1. Use `ldaps://<domain-controller>:636`; do not use cleartext LDAP.
2. Mount the issuing CA into Keycloak's trust store.
3. Use a dedicated read-only bind account stored in an approved secret store.
4. Scope the users DN and group search to the workshop organizational units.
5. Use read-only edit mode and test connection, authentication, and user sync.
6. Validate an AD user through the full frontend OIDC flow.

Do not claim this extension is complete when only TCP connectivity or user import works.
Certificate validation, credential protection, group mapping, account lifecycle, and an
end-to-end sign-in are part of the identity boundary.

## Cleanup

Stop foreground port-forwards with <kbd>Ctrl</kbd>+<kbd>C</kbd>. Remove only
workshop-scoped Entra assignments or the non-gallery enterprise application when it is
no longer needed, following your organization's change process. Do not delete shared
Keycloak, Radius, AKS, K3s, or Bastion resources as part of this challenge.

For the K3s Bastion tunnel itself:

```bash
bash resources/prepare-k3s-azure-vm.sh status
bash resources/prepare-k3s-azure-vm.sh disconnect
```

Disconnecting the local tunnel does not delete Azure Bastion, which continues to incur
cost until the workshop resource group or Bastion resource is removed through the
narrow cleanup process in [Prepare K3s on a private Azure VM](../../docs/prepare-k3s.md).
