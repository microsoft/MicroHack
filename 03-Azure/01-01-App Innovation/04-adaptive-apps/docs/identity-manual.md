---
title: Adaptive Apps identity manual reference
description: Target-neutral Keycloak and OIDC commands behind the Challenge 07 helpers.
---

## Choose the amount of automation

The [Challenge 07 walkthrough](../walkthrough/challenge-07/solution-07.md)
keeps the identity decisions and both sign-ins visible. The
[helper source](../resources/configure-identity.sh) extracts repeated mechanics:

| Action | What it does | What you still do |
| --- | --- | --- |
| `check` | Reads target bindings and broker health | Select the target; reconnect Bastion if needed |
| `setup` | Reconciles realm/client and the K3s test user | Inspect the contract; explicitly request initial admin rotation |
| `deploy` | Preserves current app inputs and enables OIDC | Supply the existing frontend password; prove browser login |

Entra application creation, assignment, SAML federation and claim mapping remain manual.
No helper creates an Azure resource, opens an endpoint or configures your tenant.

Use the following target-neutral commands instead of `setup` and `deploy` when you
want to perform the administration yourself. Run them from the Adaptive Apps
MicroHack directory, in a disposable Bash shell in the devcontainer or WSL Linux
filesystem. Do not mix the helper's temporary sessions with these manual variables.
Stop both foreground port-forwards before changing targets.

## Select and verify one target

Choose `TARGET=k3s` first, then repeat this reference with `TARGET=aks`.
K3s must already have a live Bastion tunnel:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
```

In the disposable Bash shell:

```bash
set -euo pipefail
umask 077
TARGET=k3s
GROUP=rg-trading
case "$TARGET" in
  k3s)
    export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
    CONTEXT=k3s-azure-vm
    WORKSPACE=ws-local-prod
    ENVIRONMENT=env-local-prod
    ;;
  aks)
    unset KUBECONFIG
    CONTEXT=aks-adaptive-apps
    WORKSPACE=ws-azure-prod
    ENVIRONMENT=env-azure-prod
    ;;
  *) echo "Choose k3s or aks." >&2; exit 1 ;;
esac
kubectl config use-context "$CONTEXT"
rad workspace switch "$WORKSPACE"
rad group switch "$GROUP"
rad env switch "$ENVIRONMENT"
bash resources/configure-identity.sh "$TARGET" check
```

`check` is optional automation even on the manual route. To reproduce it manually,
compare `kubectl config current-context` with the target above; compare
`rad workspace show --output json` with the same command using
`--workspace "$WORKSPACE"`. Both must have the intended `.connection.context`,
`.scope` ending in `/resourceGroups/rg-trading`, and `.environment` ending in the
intended environment name. Radius does not serialize a workspace `.name`.
Confirm `rad group show "$GROUP"` and
`rad env show "$ENVIRONMENT" --group "$GROUP"` refer to that group, then run
`kubectl rollout status deployment/core-keycloak -n core --timeout=10m`.
Do not continue with a mismatched or unhealthy target.

## Authenticate to the existing broker

`master` is for administration. Application clients/users belong in `adaptive-apps`.
Use an independent temporary admin-session file, not a persistent CLI session.
The current password is sent through stdin; if you press Enter, the pod uses the
credential mounted from its current Kubernetes Secret.

```bash
KEYCLOAK_POD="$(kubectl get pods -n core \
  -l app.kubernetes.io/component=keycloak \
  --field-selector status.phase=Running -o json |
  jq -er '.items | sort_by(.metadata.name) | .[0].metadata.name')"
ADMIN_CONFIG="$(kubectl exec -n core "$KEYCLOAK_POD" -- sh -c '
  umask 077
  path="$(mktemp /tmp/adaptive-apps-admin.XXXXXX)" || exit 1
  printf "{}\n" >"$path" || exit 1
  printf "%s\n" "$path"
')"
PARAMETERS=''
DEPLOY_LOG=''
cleanup() {
  STATUS=$?
  trap - EXIT
  if [ -n "$ADMIN_CONFIG" ]; then
    kubectl exec -n core "$KEYCLOAK_POD" -- rm -f -- "$ADMIN_CONFIG" || {
      echo "Remove admin session $ADMIN_CONFIG from pod $KEYCLOAK_POD." >&2
      STATUS=1
    }
  fi
  if [ -n "$PARAMETERS" ]; then
    rm -f -- "$PARAMETERS" || {
      echo "Remove sensitive parameter file $PARAMETERS locally." >&2
      STATUS=1
    }
  fi
  if [ -n "$DEPLOY_LOG" ]; then
    rm -f -- "$DEPLOY_LOG" || {
      echo "Remove sensitive deployment log $DEPLOY_LOG locally." >&2
      STATUS=1
    }
  fi
  unset PASSWORD CLIENT_SECRET AUTH_PASSWORD
  exit "$STATUS"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
read -rsp "Current Keycloak admin password (Enter uses the pod Secret): " PASSWORD
printf '\n'
printf '%s\n' "$PASSWORD" |
  kubectl exec -i -n core "$KEYCLOAK_POD" -- sh -c '
    IFS= read -r password
    /opt/keycloak/bin/kcadm.sh config credentials --config "$1" \
      --server http://127.0.0.1:8080 --realm master \
      --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
      --password "${password:-$KC_BOOTSTRAP_ADMIN_PASSWORD}" \
      >/dev/null 2>&1 || {
        echo "Admin authentication failed; check the current password and Helm/database drift." >&2
        exit 1
      }
  ' sh "$ADMIN_CONFIG"
unset PASSWORD
kc() {
  kubectl exec -n core "$KEYCLOAK_POD" -- \
    /opt/keycloak/bin/kcadm.sh "$@" --config "$ADMIN_CONFIG"
}
kc_write() {
  kubectl exec -i -n core "$KEYCLOAK_POD" -- \
    /opt/keycloak/bin/kcadm.sh "$@" --config "$ADMIN_CONFIG" --file -
}
set_user_password() {
  kubectl exec -i -n core "$KEYCLOAK_POD" -- sh -c '
    IFS= read -r username
    IFS= read -r password
    /opt/keycloak/bin/kcadm.sh set-password --config "$1" --realm "$2" \
      --username "$username" --new-password "$password" --temporary=false \
      >/dev/null 2>&1 || {
        echo "Password update failed; stop before changing the Secret or restarting." >&2
        exit 1
      }
  ' sh "$ADMIN_CONFIG" "$1"
}
```

Passwords become CLI arguments only inside the trusted pod. Keep local shell
tracing/transcription disabled and use an approved password manager. Secret values
still exist in process memory, pod configuration and Radius deployment state; this
workshop does not provide production-grade secret storage.

## Reconcile the application realm and client

The client ID and callback are the same on both targets, but their client IDs in the
Keycloak database and their secrets are independent.

```bash
REALM_EXISTS="$(kc get realms --realm master |
  jq -er 'any(.[]; .realm == "adaptive-apps") | tostring')"
if [ "$REALM_EXISTS" = false ]; then
  kc create realms --realm master --set realm=adaptive-apps --set enabled=true
else
  kc update realms/adaptive-apps --realm master --set enabled=true
fi
CLIENT_UUID="$(kc get clients --realm adaptive-apps \
  --query clientId=adaptive-apps |
  jq -r '.[] | select(.clientId == "adaptive-apps") | .id')"
CLIENT_SPEC='{
  "clientId":"adaptive-apps", "name":"Adaptive Apps frontend",
  "enabled":true, "protocol":"openid-connect", "publicClient":false,
  "clientAuthenticatorType":"client-secret", "standardFlowEnabled":true,
  "implicitFlowEnabled":false, "directAccessGrantsEnabled":false,
  "serviceAccountsEnabled":false,
  "redirectUris":["http://localhost:3000/*"],
  "webOrigins":["http://localhost:3000"]
}'
if [ -z "$CLIENT_UUID" ]; then
  printf '%s' "$CLIENT_SPEC" | kc_write create clients --realm adaptive-apps
else
  printf '%s' "$CLIENT_SPEC" |
    kc_write update "clients/$CLIENT_UUID" --realm adaptive-apps
fi
CLIENT_UUID="$(kc get clients --realm adaptive-apps \
  --query clientId=adaptive-apps |
  jq -er '.[] | select(.clientId == "adaptive-apps") | .id')"
kc get "clients/$CLIENT_UUID" --realm adaptive-apps |
  jq '{clientId,enabled,publicClient,standardFlowEnabled,
    implicitFlowEnabled,directAccessGrantsEnabled,serviceAccountsEnabled,
    redirectUris,webOrigins}'
```

## Create a local user on K3s only

Do not use the administrator as the application user. A rerun retains an existing
user password. If a previous attempt created the user but failed while setting its
password, deliberately use `--reset-local-password` on the helper or set it through
`set_user_password adaptive-apps` using the same stdin format below.

```bash
if [ "$TARGET" = k3s ]; then
  USER_EXISTS="$(kc get users --realm adaptive-apps --query username=local-trader |
    jq -er 'any(.[]; .username == "local-trader") | tostring')"
  if [ "$USER_EXISTS" = false ]; then
    read -rsp "Password for local-trader: " PASSWORD
    printf '\n'
    test -n "$PASSWORD" || { echo "Local password cannot be empty." >&2; exit 1; }
    kc create users --realm adaptive-apps \
      --set username=local-trader --set enabled=true \
      --set firstName=Local --set lastName=Trader \
      --set email=local-trader@example.invalid --set emailVerified=true
    printf '%s\n%s\n' local-trader "$PASSWORD" | set_user_password adaptive-apps
    unset PASSWORD
  fi
fi
```

## Rotate the administrator before initial browser exposure

Run this once for each broker's initial workshop setup, with different approved
passwords. Do not rotate on every retry.

```bash
ADMIN_USERNAME="$(kubectl get secret core-keycloak-admin -n core -o json |
  jq -er '.data.username | @base64d')"
read -rsp "New admin password (save it in your password manager): " PASSWORD
printf '\n'
test -n "$PASSWORD" || { echo "Admin password cannot be empty." >&2; exit 1; }
printf '%s\n%s\n' "$ADMIN_USERNAME" "$PASSWORD" | set_user_password master
if ! printf '%s\n%s\n' "$ADMIN_USERNAME" "$PASSWORD" |
  jq -Rn '[inputs] | {stringData:{username:.[0],password:.[1]}}' |
  kubectl patch secret core-keycloak-admin -n core \
    --type merge --patch-file /dev/stdin; then
  echo "Password changed, but Secret update failed. Do NOT restart Keycloak." >&2
  echo "Retain the chosen password and retry only the Secret patch." >&2
  exit 1
fi
unset PASSWORD
kubectl exec -n core "$KEYCLOAK_POD" -- rm -f -- "$ADMIN_CONFIG"
ADMIN_CONFIG=''
kubectl rollout restart deployment/core-keycloak -n core
kubectl rollout status deployment/core-keycloak -n core --timeout=10m
```

The rollout invalidates the pod name and admin session. Repeat **Authenticate to the
existing broker** before any further admin command. If the Secret patch failed,
use the chosen password from your password manager to retry the patch, without
restarting the broker or resetting the password again. The patch reads stdin and does
not add a secret-bearing `last-applied-configuration` annotation.

The Secret is Helm-managed. A subsequent portfolio upgrade with stale chart values
can restore the old Secret while the database retains the rotated password. Keep the
approved Helm credential values aligned. Do not attempt to recover passwords by
printing pod environment values.

## Redeploy through the existing optional OIDC contract

You can use the separate `deploy` helper even if you performed setup manually. It
recovers the running frontend/backend image, auth username, cookie secret, workload
client/tenant IDs, service account and Istio setting into owner-only temporary
storage. It requires compatible frontend/backend settings and literal environment
values. Unsupported shapes fail before `rad deploy`, rather than resetting values.
Empty literal values are preserved even when Kubernetes omits their `value` field.

For a fully manual deployment, first repeat broker authentication above and obtain
the current client UUID. Keep your original Challenge 06 non-secret parameter values
available, including custom images or workload settings. The example below uses the
standard Challenge 06 defaults; replace every changed value with your team's previous
inputs. Supply the previous cookie secret if you customized it; never put it in a
command argument or a committed file.

```bash
CLIENT_UUID="$(kc get clients --realm adaptive-apps \
  --query clientId=adaptive-apps |
  jq -er '.[] | select(.clientId == "adaptive-apps") | .id')"
CLIENT_SECRET="$(kc get "clients/$CLIENT_UUID/client-secret" \
  --realm adaptive-apps | jq -er '.value')"
read -rsp "Existing frontend break-glass password: " AUTH_PASSWORD
printf '\n'
read -rsp "Previous custom session secret (Enter uses the unchanged model default): " PASSWORD
printf '\n'
test -n "$AUTH_PASSWORD" || { echo "Frontend password cannot be empty." >&2; exit 1; }
PARAMETERS="$(mktemp /tmp/adaptive-apps-deploy.XXXXXX)"
DEPLOY_LOG="$(mktemp /tmp/adaptive-apps-deploy-log.XXXXXX)"
chmod 600 "$PARAMETERS"
printf '%s\n%s\n%s\n' "$AUTH_PASSWORD" "$CLIENT_SECRET" "$PASSWORD" |
  jq -Rn '[inputs] as $v | {
    "$schema":"https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    contentVersion:"1.0.0.0",
    parameters:({authPassword:{value:$v[0]},oidcClientSecret:{value:$v[1]}} +
      if $v[2] == "" then {} else {sessionSecret:{value:$v[2]}} end)
  }' >"$PARAMETERS"
unset AUTH_PASSWORD CLIENT_SECRET PASSWORD
ISSUER=http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps
DEPLOY_STATUS=0
rad deploy iac/app.bicep \
  --workspace "$WORKSPACE" --group "$GROUP" --environment "$ENVIRONMENT" \
  --parameters "@$PARAMETERS" \
  --parameters imageRegistry=ghcr.io/microsoft/adaptive-apps \
  --parameters imageTag=latest --parameters authUsername=admin \
  --parameters backendClientId= --parameters frontendClientId= \
  --parameters workloadIdentityServiceAccountName=default \
  --parameters workloadIdentityTenantId= --parameters enableIstioInjection=true \
  --parameters oidcClientId=adaptive-apps \
  --parameters "oidcIssuer=$ISSUER" \
  --parameters "oidcAuthEndpoint=$ISSUER/protocol/openid-connect/auth" \
  --parameters "oidcTokenEndpoint=$ISSUER/protocol/openid-connect/token" \
  --parameters "oidcUserInfoEndpoint=$ISSUER/protocol/openid-connect/userinfo" \
  --parameters oidcBrowserAuthEndpoint=http://localhost:8080/realms/adaptive-apps/protocol/openid-connect/auth \
  --parameters appBaseUrl=http://localhost:3000 \
  >"$DEPLOY_LOG" 2>&1 || DEPLOY_STATUS=$?
if [ "$DEPLOY_STATUS" -ne 0 ]; then
  echo "rad deploy failed (exit $DEPLOY_STATUS); sensitive CLI output is not printed." >&2
  echo "Check Radius deployment status; temporary parameters and logs will be removed." >&2
  exit 1
fi
rm -f -- "$PARAMETERS" "$DEPLOY_LOG"
PARAMETERS=''
DEPLOY_LOG=''
```

The traps remove sensitive files on success, command failure and catchable termination.
SIGKILL, host loss or filesystem errors cannot guarantee cleanup. On the trusted lab
workstation, remove only the exact leftover path reported by an error. Never sweep
other participants' temporary directories.

Radius and Kubernetes resource dumps can contain inline secrets. Do not capture
`rad resource show`, entire Deployments, pod environments or raw frontend logs as
evidence. The upstream frontend can log user profile information. Use configuration
projections, graph/resource lists and an authenticated test identity instead.

Return to the [walkthrough](../walkthrough/challenge-07/solution-07.md) for foreground
port-forwarding, Entra federation, both browser sign-ins, comparison and cleanup.

## Troubleshooting by layer

| Symptom | Check and next action |
| --- | --- |
| K3s API refuses localhost port 16443 | Reconnect Bastion; select the dedicated kubeconfig |
| Target check fails | Compare context, active/named workspace bindings, group and environment; do not bypass the guard |
| Authentication fails after a portfolio upgrade | Supply the current approved admin password; reconcile Helm values and the database/Secret boundary |
| Setup failed after creating the local user | Rerun with `--reset-local-password` only if a password retry is intended |
| Missing input or image mismatch during deployment | Use the manual deployment above with explicit previous inputs, not default guesses |
| `rad deploy` fails | Helper output is redacted because CLI errors can contain parameters; inspect deployment status locally in Radius and retry the manual route on a trusted terminal without recording |
| No OIDC option | Check only OIDC environment names and the documented non-secret settings; do not dump values |
| Browser cannot reach Keycloak | Browser uses localhost:8080, not cluster DNS; verify the foreground forward |
| Invalid redirect | Client includes `http://localhost:3000/*`; callback is `/auth/oidc/callback` |
| Keycloak login succeeds but callback fails | Check target-specific secret, internal token/user-info endpoints and both forwards |
| Entra rejects access | Check intended tenant, unique Entity ID, exact Reply URL and narrow user/group assignment |
| Entra option missing | Check provider alias `entra`, enabled state and imported metadata |
| Claims missing | Check the three Attribute Importer mappers and `FORCE`/`INHERIT` sync settings |
| Intermittent invalid authorization code | The two Keycloak replicas must form a healthy Infinispan/JGroups cluster; repair cache discovery rather than weakening OIDC |

## Optional local directory extension

If a real AD DS deployment already exists, you can replace K3s local users with LDAP
federation. Use LDAPS, a trusted CA, a dedicated read-only bind account, scoped users
DN/group searches and approved secret storage. Validate certificate trust, account
lifecycle, mappings and a complete AD-user frontend sign-in. Connectivity or user
import alone does not complete this extension.

## Production boundary

HTTP localhost and wildcard workshop callbacks are lab-only settings. Production needs
stable HTTPS broker/application hostnames, restricted redirects/origins, managed
certificates, durable credential rotation and an availability plan. End-user sign-in
does not replace Radius control-plane identity, workload identity or MQTT authorization.

See the official [Keycloak administration guide](https://www.keycloak.org/docs/latest/server_admin/)
and [Entra SAML setup](https://learn.microsoft.com/entra/identity/enterprise-apps/add-application-portal-setup-sso)
for the underlying administration concepts.
