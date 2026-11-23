#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# Dependency-free CLI stubs: no Kubernetes, Radius or tenant requests are made.
set -euo pipefail

test_error() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

record_call() {
  printf '%q ' "$@" >>"${case_dir}/calls"
  printf '\n' >>"${case_dir}/calls"
}

rad() {
  record_call rad "$@"
  local scope='/planes/radius/local/resourceGroups/rg-trading'
  local name=env-local-prod context=k3s-azure-vm
  if [[ "${test_target}" == aks ]]; then
    name=env-azure-prod
    context=aks-adaptive-apps
  fi
  case "$1 $2" in
    "workspace show")
      [[ "${scenario}" != workspace ]] || context=wrong-context
      if [[ "${scenario}" == workspace-alias && "$*" != *"--workspace"* ]]; then
        context=wrong-context
      fi
      [[ "${scenario}" != group ]] || scope='/planes/radius/local/resourceGroups/wrong'
      [[ "${scenario}" != environment ]] || name=wrong-environment
      jq -n --arg scope "${scope}" --arg context "${context}" \
        --arg env "${scope}/providers/Applications.Core/environments/${name}" \
        '{connection:{context:$context},scope:$scope,environment:$env}'
      ;;
    "group show") printf '{"name":"rg-trading"}\n' ;;
    "env show")
      [[ "${scenario}" != environment-api ]] || return 1
      jq -n --arg name "${name}" \
        --arg id "${scope}/providers/Applications.Core/environments/${name}" \
        '{name:$name,id:$id,properties:{compute:{namespace:$name}}}'
      ;;
    deploy*)
      local arg file=''
      for arg in "$@"; do
        if [[ "${arg}" == @* ]]; then file="${arg#@}"; fi
      done
      [[ -n "${file}" ]] || return 1
      [[ -n "$(find "${file}" -perm 0600 -print)" ]] || return 1
      cp "${file}" "${case_dir}/saved-parameters.json"
      if [[ "${scenario}" == deploy-failure ]]; then
        printf 'Synthetic sensitive error: fixture-client-secret-%s\n' "${test_target}" >&2
        return 17
      fi
      if [[ "${scenario}" == interrupted ]]; then
        kill -TERM "$$"
      fi
      printf 'Deployment succeeded.\n'
      ;;
    *) printf 'Unexpected rad call\n' >&2; return 1 ;;
  esac
}

fixture_deployment() {
  jq -n --arg scenario "${scenario}" --arg target "${test_target}" '
    def env($name; $value): {name:$name,value:$value};
    def deployment($name):
      {metadata:{name:$name},spec:{template:{
        metadata:{annotations:{"sidecar.istio.io/inject":"true"}},
        spec:{serviceAccountName:"custom-account",containers:[{
          name:$name,image:("custom.registry/trading/" + $name + ":custom-tag"),
          env:([
            env("AZURE_CLIENT_ID"; ($name + "-client")),
            env("AZURE_TENANT_ID"; "custom-tenant")
          ] + (if $name == "frontend" then [
            env("AUTH_USERNAME";"custom-admin"),
            env("AUTH_PASSWORD";"fixture-old-password"),
            env("SESSION_SECRET";"fixture-session-secret"),
            env("OIDC_CLIENT_ID";"adaptive-apps"),
            env("OIDC_CLIENT_SECRET";"fixture-client-secret"),
            env("OIDC_ISSUER";"http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps"),
            env("OIDC_AUTH_ENDPOINT";"http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps/protocol/openid-connect/auth"),
            env("OIDC_TOKEN_ENDPOINT";"http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps/protocol/openid-connect/token"),
            env("OIDC_USERINFO_ENDPOINT";"http://core-keycloak.core.svc.cluster.local:8080/realms/adaptive-apps/protocol/openid-connect/userinfo"),
            env("OIDC_BROWSER_AUTH_ENDPOINT";"http://localhost:8080/realms/adaptive-apps/protocol/openid-connect/auth"),
            env("APP_BASE_URL";"http://localhost:3000")
          ] else [] end))
        }]}
      }}};
    {items:[deployment("frontend"),deployment("backend")]} |
    if $scenario == "unsupported-inputs" then
      .items[0].spec.template.spec.containers[0].image = "custom.registry/frontend@sha256:abc"
    elif $scenario == "unsupported-istio" then
      .items[].spec.template.metadata.annotations["sidecar.istio.io/inject"] = "unexpected"
    elif $scenario == "indirect-inputs" then
      .items[0].spec.template.spec.containers[0].env[0] =
        {name:"AZURE_CLIENT_ID",valueFrom:{secretKeyRef:{name:"identity",key:"client"}}}
    elif $scenario == "missing-input" then
      .items[0].spec.template.spec.containers[0].env |=
        map(select(.name != "AZURE_CLIENT_ID"))
    elif $scenario == "duplicate-input" then
      .items[0].spec.template.spec.containers[0].env +=
        [{name:"AZURE_CLIENT_ID",value:"another-client"}]
    elif $scenario == "malformed-input" then
      .items[0].spec.template.spec.containers[0].env[0].value = null
    elif $scenario == "mixed-input" then
      .items[0].spec.template.spec.containers[0].env[0].valueFrom =
        {secretKeyRef:{name:"identity",key:"client"}}
    elif $scenario == "default-omitted" or $scenario == "default-explicit" then
      .items[].spec.template.spec.containers[0].env |= map(
        if .name == "AZURE_CLIENT_ID" or
          (.name == "AZURE_TENANT_ID" and $target == "k3s") then
          if $scenario == "default-omitted" then del(.value)
          else .value = "" end
        else . end)
    else . end
  '
}

kubectl() {
  record_call kubectl "$@"
  case "$1 $2" in
    "config current-context")
      if [[ "${scenario}" == context ]]; then printf 'wrong-context\n'
      elif [[ "${test_target}" == aks ]]; then printf 'aks-adaptive-apps\n'
      else printf 'k3s-azure-vm\n'; fi
      ;;
    "rollout status")
      [[ "${scenario}" != unhealthy ]] || return 1
      printf 'deployment successfully rolled out\n'
      ;;
    "rollout restart") touch "${case_dir}/restarted" ;;
    "get pods") printf '{"items":[{"metadata":{"name":"keycloak-test"}}]}\n' ;;
    "get secret") printf '{"data":{"username":"YWRtaW4="}}\n' ;;
    "patch secret")
      jq -e '.stringData.username == "admin" and
        .stringData.password == "fixture-new-admin"' >/dev/null
      [[ "${scenario}" != secret-failure ]] || return 1
      touch "${case_dir}/patched"
      ;;
    "get namespaces")
      [[ "${scenario}" != namespace-api ]] || return 1
      printf '{"items":[{"metadata":{"name":"%s-adaptive-apps"}}]}\n' \
        "$([[ "${test_target}" == aks ]] && printf env-azure-prod || printf env-local-prod)"
      ;;
    "get deployment")
      if [[ "$*" == *"frontend backend"* ]]; then fixture_deployment
      elif [[ "${scenario}" == missing-oidc ]]; then
        fixture_deployment | jq '.items[0] |
          .spec.template.spec.containers[0].env |=
            map(select(.name != "OIDC_TOKEN_ENDPOINT"))'
      else fixture_deployment | jq '.items[0]'; fi
      ;;
    exec*) fixture_exec "$@" ;;
    *) printf 'Unexpected kubectl call\n' >&2; return 1 ;;
  esac
}

fixture_exec() {
  local args="$*" input
  case "${args}" in
    *"mktemp /tmp/"*) printf '/tmp/adaptive-apps-admin.fixture\n' ;;
    *"rm -f -- /tmp/"*)
      [[ "${scenario}" != cleanup-failure ]] || return 1
      touch "${case_dir}/session-cleaned"
      ;;
    *"config credentials"*)
      IFS= read -r input
      [[ "${input}" == fixture-current-admin ]] || return 1
      [[ "${scenario}" != auth ]] || { printf 'Admin authentication failed.\n' >&2; return 1; }
      ;;
    *"set-password"*)
      IFS= read -r input
      [[ "${input}" == admin || "${input}" == local-trader ]] || return 1
      IFS= read -r input
      [[ "${input}" == fixture-local-password || "${input}" == fixture-new-admin ]] || return 1
      [[ "${scenario}" != password-failure ]] || return 1
      printf 'password\n' >>"${case_dir}/password-updates"
      ;;
    *"get realms"*)
      if [[ "${scenario}" == malformed ]]; then printf '{"bad":"response"}\n'
      elif [[ -e "${case_dir}/realm" || "${scenario}" == existing ]]; then
        printf '[{"realm":"adaptive-apps"}]\n'
      else printf '[]\n'; fi
      ;;
    *"create realms"*|*"update realms/adaptive-apps"*) touch "${case_dir}/realm" ;;
    *"get clients "*)
      if [[ -e "${case_dir}/client" || "${scenario}" == existing ||
        "${action}" == deploy ]]; then
        printf '[{"clientId":"adaptive-apps","id":"client-uuid"}]\n'
      else printf '[]\n'; fi
      ;;
    *"get clients/client-uuid/client-secret"*)
      printf '{"value":"fixture-client-secret-%s"}\n' "${test_target}"
      ;;
    *"get clients/client-uuid"*) cat "${case_dir}/client-spec.json" ;;
    *"create clients"*|*"update clients/"*)
      cat >"${case_dir}/client-spec.json"
      touch "${case_dir}/client"
      ;;
    *"get users "*)
      if [[ -e "${case_dir}/user" || "${scenario}" == existing ]]; then
        printf '[{"username":"local-trader","id":"user-uuid"}]\n'
      else printf '[]\n'; fi
      ;;
    *"create users"*) touch "${case_dir}/user" ;;
    *) printf 'Unexpected exec call\n' >&2; return 1 ;;
  esac
}

mktemp() {
  local path
  path="$(command mktemp "$@")"
  printf '%s\n' "${path}" >>"${case_dir}/temp-paths"
  printf '%s\n' "${path}"
}

run_helper() {
  cases_run=$((cases_run + 1))
  local expected="$1"
  shift
  local status=0
  printf '%s\n' "${answers}" |
    /bin/bash "${helper}" "${test_target}" "${action}" "$@" \
      >"${case_dir}/output" 2>&1 || status=$?
  if [[ "${expected}" == pass && "${status}" != 0 ]]; then
    cat "${case_dir}/output" >&2
    test_error "${scenario}: expected success, got ${status}"
  fi
  if [[ "${expected}" == fail && "${status}" == 0 ]]; then
    test_error "${scenario}: expected failure"
  fi
  if grep -E 'fixture-(current-admin|new-admin|local-password|old-password|session-secret|client-secret|frontend-password)' \
    "${case_dir}/output" "${case_dir}/calls" >/dev/null; then
    test_error "${scenario}: credential leaked into output or process arguments"
  fi
  local path
  if [[ -f "${case_dir}/temp-paths" ]]; then
    while IFS= read -r path; do
      [[ ! -e "${path}" ]] || test_error "Temporary files remain: ${path}"
    done <"${case_dir}/temp-paths"
  fi
}

new_case() {
  scenario="$1"
  case_dir="${test_root}/${scenario}-${test_target}"
  mkdir -p "${case_dir}"
  : >"${case_dir}/calls"
  answers='fixture-current-admin'
  export scenario case_dir answers
}

test_cleanup() {
  # This is the one exact mktemp directory owned by this test invocation.
  rm -rf -- "${test_root}"
}

main() {
  helper="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/configure-identity.sh"
  cases_run=0
  test_root="$(command mktemp -d /tmp/adaptive-apps-identity-tests.XXXXXX)"
  trap test_cleanup EXIT
  export HOME="${test_root}/home"
  mkdir -p "${HOME}/.kube"
  touch "${HOME}/.kube/adaptive-apps-k3s.yaml"
  unset KUBECONFIG
  export -f rad kubectl fixture_exec fixture_deployment record_call mktemp
  export test_target action
  local name
  for test_target in k3s aks; do
    action=check
    new_case healthy
    run_helper pass
    ! grep -E ' exec | deploy | patch | restart ' "${case_dir}/calls" >/dev/null ||
      test_error "check performed a mutation"
    if [[ "${test_target}" == k3s ]]; then
      new_case missing-kubeconfig
      mv "${HOME}/.kube/adaptive-apps-k3s.yaml" "${HOME}/.kube/saved.yaml"
      run_helper fail
      mv "${HOME}/.kube/saved.yaml" "${HOME}/.kube/adaptive-apps-k3s.yaml"
    else
      new_case stale-kubeconfig
      KUBECONFIG=wrong-kubeconfig run_helper fail
    fi
    [[ ! -s "${case_dir}/calls" ]] || test_error "Invalid kubeconfig invoked tools"
    for name in context workspace workspace-alias group environment environment-api unhealthy; do
      new_case "${name}"
      run_helper fail
      ! grep -E ' exec | deploy | patch | restart ' "${case_dir}/calls" >/dev/null ||
        test_error "failed check performed a mutation"
    done
    action=setup
    new_case create
    if [[ "${test_target}" == k3s ]]; then
      answers=$'fixture-current-admin\nfixture-local-password\nfixture-new-admin'
    else answers=$'fixture-current-admin\nfixture-new-admin'; fi
    run_helper pass --rotate-admin
    [[ -e "${case_dir}/patched" && -e "${case_dir}/restarted" &&
      -e "${case_dir}/session-cleaned" ]] || test_error "Rotation lifecycle incomplete"
    jq -e '.publicClient == false and .standardFlowEnabled == true and
      .implicitFlowEnabled == false and .directAccessGrantsEnabled == false and
      .serviceAccountsEnabled == false and
      .redirectUris == ["http://localhost:3000/*"] and
      .webOrigins == ["http://localhost:3000"]' \
      "${case_dir}/client-spec.json" >/dev/null
    local old_count
    old_count="$(wc -l <"${case_dir}/password-updates")"
    answers=fixture-current-admin
    run_helper pass
    [[ "$(wc -l <"${case_dir}/password-updates")" == "${old_count}" ]] ||
      test_error "Rerun reset a password"
    [[ "$(grep -c 'create realms' "${case_dir}/calls")" == 1 ]] ||
      test_error "Rerun duplicated the realm"
    if [[ "${test_target}" == k3s ]]; then
      answers=$'fixture-current-admin\nfixture-local-password'
      run_helper pass --reset-local-password
      [[ "$(wc -l <"${case_dir}/password-updates")" != "${old_count}" ]] ||
        test_error "Explicit reset did not change the local password"
    fi
    new_case cleanup-failure
    if [[ "${test_target}" == k3s ]]; then
      answers=$'fixture-current-admin\nfixture-local-password'
    else answers=fixture-current-admin; fi
    run_helper fail
    grep -F 'Remove admin session' "${case_dir}/output" >/dev/null
    for name in auth malformed password-failure secret-failure; do
      new_case "${name}"
      if [[ "${test_target}" == k3s ]]; then
        answers=$'fixture-current-admin\nfixture-local-password\nfixture-new-admin'
      else answers=$'fixture-current-admin\nfixture-new-admin'; fi
      run_helper fail --rotate-admin
      [[ ! -e "${case_dir}/restarted" ]] || test_error "Restart after setup failure"
      if [[ "${name}" == auth || "${name}" == malformed ]]; then
        ! grep -E 'create|update|patch|restart' "${case_dir}/calls" >/dev/null ||
          test_error "Mutation after failed authentication or malformed response"
      fi
    done
    action=deploy
    for name in deployment default-omitted default-explicit deploy-failure \
      interrupted unsupported-inputs unsupported-istio indirect-inputs \
      missing-input duplicate-input malformed-input mixed-input namespace-api \
      missing-oidc; do
      new_case "${name}"
      answers=$'fixture-current-admin\nfixture-frontend-password'
      if [[ "${name}" == deployment ]]; then
        run_helper pass
        jq -e --arg secret "fixture-client-secret-${test_target}" '
          .parameters as $p |
          $p.imageRegistry.value == "custom.registry/trading" and
          $p.imageTag.value == "custom-tag" and
          $p.authUsername.value == "custom-admin" and
          $p.authPassword.value == "fixture-frontend-password" and
          $p.sessionSecret.value == "fixture-session-secret" and
          $p.frontendClientId.value == "frontend-client" and
          $p.backendClientId.value == "backend-client" and
          $p.workloadIdentityTenantId.value == "custom-tenant" and
          $p.workloadIdentityServiceAccountName.value == "custom-account" and
          $p.enableIstioInjection.value == true and
          $p.oidcClientSecret.value == $secret
        ' "${case_dir}/saved-parameters.json" >/dev/null
        grep -F 'oidcBrowserAuthEndpoint=http://localhost:8080/' "${case_dir}/calls" >/dev/null
        grep -F 'oidcIssuer=http://core-keycloak.core.svc.cluster.local:8080/' "${case_dir}/calls" >/dev/null
      elif [[ "${name}" == default-* ]]; then
        run_helper pass
        jq -e --arg target "${test_target}" '
          .parameters as $p |
          $p.frontendClientId.value == "" and
          $p.backendClientId.value == "" and
          $p.workloadIdentityTenantId.value ==
            (if $target == "k3s" then "" else "custom-tenant" end)
        ' "${case_dir}/saved-parameters.json" >/dev/null ||
          test_error "Default identity inputs were not preserved"
      else run_helper fail; fi
      if [[ "${name}" == indirect-inputs || "${name}" == missing-input ||
        "${name}" == duplicate-input || "${name}" == malformed-input ||
        "${name}" == mixed-input ]]; then
        grep -F 'Cannot preserve current inputs' "${case_dir}/output" >/dev/null ||
          test_error "Invalid environment input did not report preservation failure"
      fi
      if [[ "${name}" == namespace-api || "${name}" == unsupported-* ||
        "${name}" == indirect-inputs || "${name}" == missing-input ||
        "${name}" == duplicate-input || "${name}" == malformed-input ||
        "${name}" == mixed-input ]]; then
        ! grep 'rad deploy' "${case_dir}/calls" >/dev/null ||
          test_error "Deployment after failed input discovery"
      fi
    done
  done
  test_target=unknown
  action=check
  new_case invalid-target
  run_helper fail
  [[ ! -s "${case_dir}/calls" ]] || test_error "Unknown target invoked tools"
  test_target=aks
  action=unknown
  new_case invalid-action
  run_helper fail
  [[ ! -s "${case_dir}/calls" ]] || test_error "Unknown action invoked tools"
  action=check
  new_case missing-tool
  local saved_path="${PATH}"
  local missing_status=0
  PATH="${case_dir}" /bin/bash "${helper}" aks check \
    >"${case_dir}/output" 2>&1 || missing_status=$?
  [[ "${missing_status}" != 0 ]] || test_error "Missing dependency accepted"
  PATH="${saved_path}"
  grep -F 'Required command not found' "${case_dir}/output" >/dev/null
  printf 'PASS: %s helper cases plus missing-tool check; target, rerun, credentials, deployment and failures.\n' "${cases_run}"
}

main "$@"
