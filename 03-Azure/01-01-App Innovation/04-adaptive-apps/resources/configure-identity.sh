#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Selective Challenge 07 actions; invoke with Bash, never with shell tracing.
set -euo pipefail

identity_error() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

identity_usage() {
  cat <<'USAGE'
Usage: bash resources/configure-identity.sh <k3s|aks> <check|setup|deploy>
       [--rotate-admin] [--reset-local-password]

check   Read-only target, Radius binding and Keycloak health checks.
setup   Reconcile the application realm/client; create a K3s local test user.
deploy  Enable OIDC in the existing application, preserving its running inputs.

Options apply only to setup. --reset-local-password is K3s-only.
Use --rotate-admin on initial setup, before browser exposure. Reruns do not
rotate administrators or reset existing user passwords unless explicitly asked.
Select the Kubernetes context and Radius workspace/group/environment first.
K3s uses ~/.kube/adaptive-apps-k3s.yaml; reconnect Bastion separately if needed.
Secrets are prompted without echo. Keep tracing and terminal recording disabled.
USAGE
}

identity_target() {
  case "$1" in
    k3s)
      context=k3s-azure-vm
      workspace=ws-local-prod
      environment=env-local-prod
      export KUBECONFIG="${HOME}/.kube/adaptive-apps-k3s.yaml"
      [[ -f "${KUBECONFIG}" ]] ||
        identity_error "K3s kubeconfig missing. Reconnect using prepare-k3s-azure-vm.sh connect."
      ;;
    aks)
      context=aks-adaptive-apps
      workspace=ws-azure-prod
      environment=env-azure-prod
      [[ -z "${KUBECONFIG:-}" ]] ||
        identity_error "Unset KUBECONFIG before selecting the AKS target."
      ;;
    *) identity_error "Unknown target. Expected k3s or aks." ;;
  esac
  group=rg-trading
}

identity_check() {
  local actual workspace_json named_workspace group_json
  actual="$(kubectl config current-context)"
  [[ "${actual}" == "${context}" ]] ||
    identity_error "Kubernetes context is ${actual}; expected ${context}."
  workspace_json="$(rad workspace show --output json |
    jq -ce '{context:.connection.context, scope, environment}')"
  named_workspace="$(rad workspace show --workspace "${workspace}" --output json |
    jq -ce '{context:.connection.context, scope, environment}')"
  [[ "${workspace_json}" == "${named_workspace}" ]] ||
    identity_error "Select Radius workspace ${workspace} before continuing."
  jq -e --arg group "${group}" --arg context "${context}" \
    --arg environment "${environment}" '
      .context == $context and
      (.scope | ascii_downcase | endswith("/resourcegroups/" + $group)) and
      (.environment | ascii_downcase |
        endswith("/environments/" + $environment) and
        contains("/resourcegroups/" + $group + "/"))
    ' \
    <<<"${workspace_json}" >/dev/null ||
    identity_error "Select Radius workspace ${workspace}, connected to ${context}."
  group_json="$(rad group show "${group}" --workspace "${workspace}" --output json)"
  jq -e --arg name "${group}" '.name == $name' \
    <<<"${group_json}" >/dev/null ||
    identity_error "Radius group must be ${group}."
  environment_json="$(rad env show "${environment}" --workspace "${workspace}" \
    --group "${group}" --output json)"
  jq -e --arg name "${environment}" --arg group "${group}" '
    .name == $name and
    (.id | ascii_downcase | contains("/resourcegroups/" + $group + "/")) and
    (.properties.compute.namespace | type == "string" and length > 0)
  ' <<<"${environment_json}" >/dev/null ||
    identity_error "Select environment ${environment} in group ${group}."
  kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
  printf 'Verified target: %s | %s | %s | %s\n' \
    "${context}" "${workspace}" "${group}" "${environment}"
}

identity_prompt() {
  local label="$1"
  IFS= read -r -s -p "${label}: " prompt_value ||
    identity_error "Credential input cancelled."
  printf '\n' >&2
  [[ "${prompt_value}" != *$'\r'* ]] ||
    identity_error "Passwords must not contain carriage returns."
}

identity_cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "${admin_config:-}" && -n "${keycloak_pod:-}" ]]; then
    if ! kubectl exec --namespace core "${keycloak_pod}" -- \
      rm -f -- "${admin_config}"; then
      printf 'ERROR: Remove admin session %s from pod %s before continuing.\n' \
        "${admin_config}" "${keycloak_pod}" >&2
      result=1
    fi
  fi
  if [[ -n "${work_dir:-}" ]]; then
    if ! rm -f -- "${work_dir}/parameters.json" "${work_dir}/deployment.json" \
      "${work_dir}/diagnostic.log" || ! rmdir -- "${work_dir}"; then
      printf 'ERROR: Sensitive temporary files remain in %s; remove them locally.\n' \
        "${work_dir}" >&2
      result=1
    fi
  fi
  unset prompt_value client_secret auth_password
  exit "${result}"
}

identity_authenticate() {
  keycloak_pod="$(kubectl get pods --namespace core \
    --selector app.kubernetes.io/component=keycloak \
    --field-selector status.phase=Running --output json |
    jq -er '.items | sort_by(.metadata.name) | .[0].metadata.name')"
  [[ -n "${keycloak_pod}" ]] || identity_error "No running Keycloak pod."
  # shellcheck disable=SC2016 # Initialize valid JSON in the pod, not a local file.
  admin_config="$(kubectl exec --namespace core "${keycloak_pod}" -- \
    /bin/sh -c '
      umask 077
      path="$(mktemp /tmp/adaptive-apps-admin.XXXXXX)" || exit 1
      printf "{}\n" >"$path" || exit 1
      printf "%s\n" "$path"
    ')"
  [[ "${admin_config}" == /tmp/adaptive-apps-admin.* &&
    "${admin_config}" != *$'\n'* ]] ||
    identity_error "Keycloak did not return a valid temporary admin-session path."
  identity_prompt "Current Keycloak admin password (Enter uses the pod's current Secret)"
  # shellcheck disable=SC2016 # Expansion belongs to the shell inside the pod.
  printf '%s\n' "${prompt_value}" |
    kubectl exec --stdin --namespace core "${keycloak_pod}" -- \
      /bin/sh -c '
        IFS= read -r password
        /opt/keycloak/bin/kcadm.sh config credentials --config "$1" \
          --server http://127.0.0.1:8080 --realm master \
          --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
          --password "${password:-$KC_BOOTSTRAP_ADMIN_PASSWORD}" \
          >/dev/null 2>&1 || {
            echo "Admin authentication failed. Supply the current approved password; check Helm/database credential drift." >&2
            exit 1
          }
      ' sh "${admin_config}"
  unset prompt_value
}

identity_kc() {
  kubectl exec --namespace core "${keycloak_pod}" -- \
    /opt/keycloak/bin/kcadm.sh "$@" --config "${admin_config}"
}

identity_kc_write() {
  kubectl exec --stdin --namespace core "${keycloak_pod}" -- \
    /opt/keycloak/bin/kcadm.sh "$@" --config "${admin_config}" --file -
}

identity_client() {
  client_uuid="$(identity_kc get clients --realm adaptive-apps \
    --query clientId=adaptive-apps |
    jq -er '[.[] | select(.clientId == "adaptive-apps")] |
      if length == 1 then .[0].id else error("Expected one adaptive-apps client") end')"
}

identity_client_summary() {
  identity_kc get "clients/${client_uuid}" --realm adaptive-apps |
    jq '{clientId, enabled, publicClient, standardFlowEnabled,
      implicitFlowEnabled, directAccessGrantsEnabled, serviceAccountsEnabled,
      redirectUris, webOrigins}'
}

identity_set_password() {
  local username="$1" password="$2" realm="$3"
  # shellcheck disable=SC2016 # Only the pod receives password arguments.
  printf '%s\n%s\n' "${username}" "${password}" |
    kubectl exec --stdin --namespace core "${keycloak_pod}" -- \
      /bin/sh -c '
        IFS= read -r username
        IFS= read -r password
        /opt/keycloak/bin/kcadm.sh set-password --config "$1" \
          --realm "$2" --username "$username" --new-password "$password" \
          --temporary=false >/dev/null 2>&1 || {
            echo "Keycloak password update failed; stop and retry with approved credentials." >&2
            exit 1
          }
      ' sh "${admin_config}" "${realm}"
}

identity_rotate_admin() {
  local username
  username="$(kubectl get secret core-keycloak-admin --namespace core \
    --output json | jq -er '.data.username | @base64d')"
  identity_prompt "New Keycloak admin password (save in your approved password manager)"
  [[ -n "${prompt_value}" ]] || identity_error "Admin password cannot be empty."
  identity_set_password "${username}" "${prompt_value}" master
  if ! printf '%s\n%s\n' "${username}" "${prompt_value}" |
    jq -Rn '[inputs] | {stringData: {username: .[0], password: .[1]}}' |
    kubectl patch secret core-keycloak-admin --namespace core \
      --type merge --patch-file /dev/stdin >/dev/null; then
    identity_error "Admin password changed but Secret update failed. Do NOT restart Keycloak. Keep the chosen password; repair the Secret using docs/identity-manual.md."
  fi
  unset prompt_value
  kubectl exec --namespace core "${keycloak_pod}" -- rm -f -- "${admin_config}"
  admin_config=''
  kubectl rollout restart deployment/core-keycloak --namespace core
  kubectl rollout status deployment/core-keycloak --namespace core --timeout=10m
  printf '%s\n' "Admin rotated. A later Helm upgrade with stale values can restore the old Secret; keep chart credentials aligned."
}

identity_setup() {
  local realms clients spec users realm_exists client_exists user_exists=false
  realms="$(identity_kc get realms --realm master)"
  realm_exists="$(jq -er 'if type == "array" then
    any(.[]; .realm == "adaptive-apps") | tostring
    else error("Invalid realm response") end' <<<"${realms}")"
  if [[ "${realm_exists}" == false ]]; then
    identity_kc create realms --realm master \
      --set realm=adaptive-apps --set enabled=true
  else
    identity_kc update realms/adaptive-apps --realm master --set enabled=true
  fi
  spec='{
    "clientId":"adaptive-apps", "name":"Adaptive Apps frontend",
    "enabled":true, "protocol":"openid-connect", "publicClient":false,
    "clientAuthenticatorType":"client-secret", "standardFlowEnabled":true,
    "implicitFlowEnabled":false, "directAccessGrantsEnabled":false,
    "serviceAccountsEnabled":false,
    "redirectUris":["http://localhost:3000/*"],
    "webOrigins":["http://localhost:3000"]
  }'
  clients="$(identity_kc get clients --realm adaptive-apps \
    --query clientId=adaptive-apps)"
  client_exists="$(jq -er 'if type == "array" then
    any(.[]; .clientId == "adaptive-apps") | tostring
    else error("Invalid client response") end' <<<"${clients}")"
  if [[ "${client_exists}" == true ]]; then
    identity_client
    printf '%s' "${spec}" |
      identity_kc_write update "clients/${client_uuid}" --realm adaptive-apps
  else
    printf '%s' "${spec}" | identity_kc_write create clients --realm adaptive-apps
    identity_client
  fi
  identity_client_summary
  if [[ "${target}" == k3s ]]; then
    users="$(identity_kc get users --realm adaptive-apps \
      --query username=local-trader)"
    user_exists="$(jq -er 'if type == "array" then
      any(.[]; .username == "local-trader") | tostring
      else error("Invalid user response") end' <<<"${users}")"
    if [[ "${user_exists}" == false || "${reset_local}" == true ]]; then
      identity_prompt "Password for local-trader (save it for browser sign-in)"
      [[ -n "${prompt_value}" ]] || identity_error "Local password cannot be empty."
      if [[ "${user_exists}" == false ]]; then
        identity_kc create users --realm adaptive-apps \
          --set username=local-trader --set enabled=true \
          --set firstName=Local --set lastName=Trader \
          --set email=local-trader@example.invalid --set emailVerified=true
      fi
      identity_set_password local-trader "${prompt_value}" adaptive-apps
      unset prompt_value
    else
      printf '%s\n' "Existing local-trader retained; use --reset-local-password only to change its password."
    fi
  fi
  if [[ "${rotate_admin}" == true ]]; then
    identity_rotate_admin
  else
    printf '%s\n' "Admin password unchanged. Initial setup requires --rotate-admin before browser exposure."
  fi
}

identity_deploy() {
  local namespace candidate containers image tag registry namespaces candidate_exists
  local issuer='http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps'
  namespace="$(jq -er '.properties.compute.namespace' <<<"${environment_json}")"
  candidate="${namespace}-adaptive-apps"
  namespaces="$(kubectl get namespaces --output json)"
  candidate_exists="$(jq -er --arg name "${candidate}" \
    'any(.items[]; .metadata.name == $name) | tostring' <<<"${namespaces}")"
  if [[ "${candidate_exists}" == true ]]; then
    namespace="${candidate}"
  fi
  work_dir="$(mktemp -d /tmp/adaptive-apps-identity.XXXXXX)"
  chmod 700 "${work_dir}"
  kubectl get deployment frontend backend --namespace "${namespace}" \
    --output json >"${work_dir}/deployment.json"
  containers="$(jq -ce '
    [.items[] | {name: .metadata.name, pod: .spec.template,
      container: (.spec.template.spec.containers[] |
        select(.name == "frontend" or .name == "backend"))}] |
    if length == 2 and ([.[].name] | sort) == ["backend","frontend"]
    then . else error("Expected existing frontend/backend deployments") end
  ' "${work_dir}/deployment.json")"
  image="$(jq -er '.[] | select(.name == "frontend") | .container.image' \
    <<<"${containers}")"
  [[ "${image}" == */frontend:* && "${image}" != *@* ]] ||
    identity_error "Cannot infer image parameters; use the manual route with your explicit Challenge 06 inputs."
  tag="${image##*:}"
  registry="${image%/frontend:*}"
  jq -e --arg image "${registry}/backend:${tag}" \
    'any(.[]; .name == "backend" and .container.image == $image)' \
    <<<"${containers}" >/dev/null ||
    identity_error "Frontend/backend image inputs differ; use the manual route with explicit prior inputs."
  if ! jq --arg registry "${registry}" --arg tag "${tag}" '
    def value($c; $n):
      [$c.container.env[] | select(.name == $n)] |
      if length != 1 or (.[0] | has("valueFrom")) then
        error("Required literal input missing; use the manual deployment route")
      elif (.[0] | has("value")) then
        if (.[0].value | type) == "string" then .[0].value
        else error("Required literal input must be a string") end
      else "" end;
    (.[] | select(.name == "frontend")) as $f |
    (.[] | select(.name == "backend")) as $b |
    ($f.pod.spec.serviceAccountName // "default") as $sa |
    ($f.pod.metadata.annotations["sidecar.istio.io/inject"] // "false") as $istio |
    if ($istio != "true" and $istio != "false") or
       ($b.pod.spec.serviceAccountName // "default") != $sa or
       ($b.pod.metadata.annotations["sidecar.istio.io/inject"] // "false") != $istio or
       value($f; "AZURE_TENANT_ID") != value($b; "AZURE_TENANT_ID")
    then error("Workload inputs differ; use the manual deployment route")
    else {
      "$schema":"https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
      contentVersion:"1.0.0.0",
      parameters: ({
        imageRegistry:$registry, imageTag:$tag,
        authUsername:value($f; "AUTH_USERNAME"),
        sessionSecret:value($f; "SESSION_SECRET"),
        frontendClientId:value($f; "AZURE_CLIENT_ID"),
        backendClientId:value($b; "AZURE_CLIENT_ID"),
        workloadIdentityTenantId:value($f; "AZURE_TENANT_ID"),
        workloadIdentityServiceAccountName:$sa,
        enableIstioInjection:($istio == "true")
      } | with_entries(.value = {value:.value}))
    } end
  ' <<<"${containers}" >"${work_dir}/parameters.json"; then
    identity_error "Cannot preserve current inputs. Use docs/identity-manual.md with your explicit previous parameters."
  fi
  unset containers
  rm -f -- "${work_dir}/deployment.json"
  identity_client
  client_secret="$(identity_kc get "clients/${client_uuid}/client-secret" \
    --realm adaptive-apps | jq -er '.value | select(type == "string" and length > 0)')"
  identity_prompt "Existing frontend break-glass password"
  [[ -n "${prompt_value}" ]] || identity_error "Frontend password cannot be empty."
  printf '%s\n%s\n' "${prompt_value}" "${client_secret}" |
    jq -Rn --slurpfile previous "${work_dir}/parameters.json" '
      [inputs] as $secrets | $previous[0] |
      .parameters.authPassword = {value:$secrets[0]} |
      .parameters.oidcClientSecret = {value:$secrets[1]}
    ' >"${work_dir}/deployment.json"
  mv -- "${work_dir}/deployment.json" "${work_dir}/parameters.json"
  unset prompt_value client_secret
  printf 'Preserving images: %s/{frontend,backend}:%s\n' "${registry}" "${tag}"
  printf 'Pod issuer: %s\nBrowser auth: %s\n' "${issuer}" \
    'http://localhost:8080/realms/adaptive-apps/protocol/openid-connect/auth'
  local deploy_status=0
  rad deploy "${microhack_dir}/iac/app.bicep" \
    --workspace "${workspace}" --group "${group}" --environment "${environment}" \
    --parameters "@${work_dir}/parameters.json" \
    --parameters oidcClientId=adaptive-apps \
    --parameters "oidcIssuer=${issuer}" \
    --parameters "oidcAuthEndpoint=${issuer}/protocol/openid-connect/auth" \
    --parameters "oidcTokenEndpoint=${issuer}/protocol/openid-connect/token" \
    --parameters "oidcUserInfoEndpoint=${issuer}/protocol/openid-connect/userinfo" \
    --parameters oidcBrowserAuthEndpoint=http://localhost:8080/realms/adaptive-apps/protocol/openid-connect/auth \
    --parameters appBaseUrl=http://localhost:3000 \
    >"${work_dir}/diagnostic.log" 2>&1 || deploy_status=$?
  [[ "${deploy_status}" == 0 ]] ||
    identity_error "rad deploy failed (exit ${deploy_status}); secret-bearing CLI output is not printed. Temporary parameters/logs will be removed. Check Radius deployment status and the manual troubleshooting guide."
  kubectl rollout status deployment/frontend --namespace "${namespace}" --timeout=5m
  kubectl get deployment frontend --namespace "${namespace}" --output json |
    jq -e --arg issuer "${issuer}" '
      .spec.template.spec.containers[] | select(.name == "frontend") |
      [.env[] | {key:.name,value:.value}] | from_entries |
      .OIDC_CLIENT_ID == "adaptive-apps" and
      (.OIDC_CLIENT_SECRET | type == "string" and length > 0) and
      .OIDC_ISSUER == $issuer and
      .OIDC_AUTH_ENDPOINT == ($issuer + "/protocol/openid-connect/auth") and
      .OIDC_TOKEN_ENDPOINT == ($issuer + "/protocol/openid-connect/token") and
      .OIDC_USERINFO_ENDPOINT == ($issuer + "/protocol/openid-connect/userinfo") and
      .OIDC_BROWSER_AUTH_ENDPOINT == "http://localhost:8080/realms/adaptive-apps/protocol/openid-connect/auth" and
      .APP_BASE_URL == "http://localhost:3000"
    ' \
      >/dev/null ||
    identity_error "Frontend rollout completed without the expected OIDC settings."
  printf '%s\n' "Deployment checks passed, NOT authentication. Complete the private-browser sign-in and compare the Radius graphs."
}

main() {
  # Secrets must not be inherited by a caller's xtrace/verbose settings.
  case "$-" in *x*|*v*) set +xv; identity_error "Disable shell tracing before using this helper." ;; esac
  if [[ "${1:-}" == --help ]]; then identity_usage; return; fi
  [[ $# -ge 2 ]] || { identity_usage >&2; exit 1; }
  target="$1"
  local action="$2" command_name
  shift 2
  [[ "${target}" == k3s || "${target}" == aks ]] ||
    identity_error "Unknown target. Expected k3s or aks."
  [[ "${action}" == check || "${action}" == setup || "${action}" == deploy ]] ||
    identity_error "Unknown action. Expected check, setup or deploy."
  rotate_admin=false
  reset_local=false
  while (( $# )); do
    [[ "${action}" == setup ]] || identity_error "Options apply only to setup."
    case "$1" in
      --rotate-admin) rotate_admin=true ;;
      --reset-local-password)
        [[ "${target}" == k3s ]] || identity_error "Local passwords apply only to K3s."
        reset_local=true ;;
      *) identity_error "Unknown option: $1" ;;
    esac
    shift
  done
  for command_name in kubectl rad jq mktemp chmod rm rmdir mv; do
    command -v "${command_name}" >/dev/null ||
      identity_error "Required command not found: ${command_name}"
  done
  umask 077
  microhack_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  work_dir=''
  admin_config=''
  keycloak_pod=''
  trap identity_cleanup EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  identity_target "${target}"
  identity_check
  [[ "${action}" != check ]] || return 0
  identity_authenticate
  case "${action}" in
    setup) identity_setup ;;
    deploy) identity_deploy ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
