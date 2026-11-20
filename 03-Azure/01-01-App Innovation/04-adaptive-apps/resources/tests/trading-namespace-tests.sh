#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
# CLI stubs keep these checks independent of Kubernetes, Radius, and Azure.
set -euo pipefail

command -v jq >/dev/null || { echo "Required command not found: jq" >&2; exit 1; }
unset RADIUS_GROUP
resources="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

record_call() {
  printf '%q ' "$@" >>"${case_dir}/calls"
  printf '\n' >>"${case_dir}/calls"
}

rad() {
  record_call rad "$@"
  [[ "$1 $2" == "env show" ]] || return 1
  [[ "$*" == *"--workspace ws-${target}-prod"* ]] || return 1
  [[ "$*" == *"--group rg-trading"* ]] || return 1
  case "$scenario" in
    environment-api) echo "Environment lookup denied." >&2; return 1 ;;
    environment-missing) printf '{"properties":{"compute":{}}}\n' ;;
    *) printf '{"properties":{"compute":{"namespace":"env-%s-prod"}}}\n' "$target" ;;
  esac
}

kubectl() {
  record_call kubectl "$@"
  local namespace='' args="$*" previous='' argument
  for argument in "$@"; do
    [[ "$previous" != "--namespace" ]] || namespace="$argument"
    previous="$argument"
  done
  case "$1 $2" in
    "config current-context") printf 'fixture-context\n' ;;
    "get jobs")
      [[ "$args" == *"--selector app=postgres-schema-initializer,resource=trading-db"* ]] ||
        return 1
      if [[ "$args" == *"--all-namespaces"* ]]; then
        case "$scenario" in
          diagnostic-denied) echo "Forbidden: cannot list jobs across namespaces." >&2; return 1 ;;
          diagnostic-malformed) printf '{"items":null}\n'; return ;;
          diagnostic-none) printf '{"items":[]}\n'; return ;;
          diagnostic-multiple)
            printf '{"items":[{"metadata":{"namespace":"env-azure-prod-adaptive-apps"}},{"metadata":{"namespace":"env-local-prod-adaptive-apps"}}]}\n'
            return ;;
          *)
            printf '{"items":[{"metadata":{"namespace":"env-azure-prod-adaptive-apps"}},{"metadata":{"namespace":"env-azure-prod-adaptive-apps"}}]}\n'
            return ;;
        esac
      fi
      case "$scenario" in
        namespace-api) echo "Forbidden: cannot list jobs in namespace." >&2; return 1 ;;
        namespace-malformed) printf '{"items":null}\n'; return ;;
        none|diagnostic-*) printf '{"items":[]}\n'; return ;;
        missing-namespace)
          if [[ "$namespace" == "env-${target}-prod-adaptive-apps" ]]; then return; fi ;;
      esac
      if [[ "$scenario" == both || "$scenario" == success ||
        ("$scenario" == application && "$namespace" == "env-${target}-prod-adaptive-apps") ||
        ("$scenario" == environment && "$namespace" == "env-${target}-prod") ||
        ("$scenario" == missing-namespace && "$namespace" == "env-${target}-prod") ]]; then
        printf '{"items":[{"metadata":{"name":"older-schema","creationTimestamp":"2026-01-01T00:00:00Z"}},{"metadata":{"name":"fixture-schema","creationTimestamp":"2026-02-01T00:00:00Z"}}]}\n'
      else
        printf '{"items":[]}\n'
      fi
      ;;
    "get job")
      printf '%s\n' '{"spec":{"template":{"spec":{"containers":[{"env":[
        {"name":"PGHOST","value":"fixture-host"},
        {"name":"PGDATABASE","value":"trading"},
        {"name":"PGUSER","value":"fixture-user"},
        {"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"fixture-credentials","key":"password"}}}
      ]}]}}}}'
      ;;
    "wait --namespace") printf 'condition met\n' ;;
    "create -f")
      jq -e --arg namespace "$APP_NAMESPACE" '
        .metadata.namespace == $namespace and
        (.spec.containers | length == 2) and
        any(.spec.containers[0].env[]; .name == "PGSSLMODE" and .value == "prefer")
      ' >/dev/null || return 1
      printf 'fixture-verification\n'
      ;;
    "get pod") printf 'Succeeded\n' ;;
    logs*) printf 'fixture container output\n' ;;
    "delete pod") printf 'fixture verification pod deleted\n' ;;
    *) echo "Unexpected kubectl call: $args" >&2; return 1 ;;
  esac
}

export -f record_call rad kubectl
export case_dir scenario target
cases=0
run_case() {
  local expected="$1" script="$2" status=0
  shift 2
  cases=$((cases + 1))
  case_dir="${test_root}/case-${cases}"
  mkdir -p "$case_dir"
  : >"${case_dir}/calls"
  bash "${resources}/${script}" "$@" >"${case_dir}/output" 2>"${case_dir}/error" || status=$?
  if [[ "$expected" == pass && "$status" != 0 || "$expected" == fail && "$status" == 0 ]]; then
    cat "${case_dir}/output" "${case_dir}/error" >&2
    echo "FAIL: $script/$scenario expected $expected, got exit $status" >&2
    exit 1
  fi
}
assert_contains() {
  grep -Fq "$2" "${case_dir}/$1" || {
    cat "${case_dir}/$1" >&2
    echo "FAIL: missing '$2' in $1 for $scenario" >&2
    exit 1
  }
}
assert_read_only() {
  if grep -E '^kubectl (create|delete|wait|logs)|^rad deploy' "${case_dir}/calls"; then
    echo "FAIL: discovery or failed verification changed resources" >&2
    exit 1
  fi
}

for target in azure local; do
  for scenario in application environment missing-namespace; do
    run_case pass resolve-trading-namespace.sh "ws-${target}-prod" "env-${target}-prod"
    expected="env-${target}-prod"
    [[ "$scenario" != application ]] || expected="${expected}-adaptive-apps"
    [[ "$(cat "${case_dir}/output")" == "$expected" ]] || {
      echo "FAIL: incorrect namespace for $target/$scenario" >&2; exit 1;
    }
    assert_read_only
  done
done
target=azure
for scenario in both none environment-api environment-missing namespace-api namespace-malformed; do
  run_case fail resolve-trading-namespace.sh ws-azure-prod env-azure-prod
  [[ ! -s "${case_dir}/output" ]] || { echo "FAIL: failed discovery printed a namespace"; exit 1; }
  [[ -s "${case_dir}/error" ]] || { echo "FAIL: discovery error was silent"; exit 1; }
  assert_read_only
done

export APP_NAMESPACE=env-azure-prod
for scenario in namespace-api namespace-malformed; do
  run_case fail verify-trading-db.sh
  [[ -s "${case_dir}/error" ]] || { echo "FAIL: namespace lookup error was silent"; exit 1; }
  ! grep -Fq -- '--all-namespaces' "${case_dir}/calls" ||
    { echo "FAIL: namespace lookup error was treated as a missing Job"; exit 1; }
  assert_read_only
done
for scenario in diagnostic-one diagnostic-multiple diagnostic-none diagnostic-denied diagnostic-malformed; do
  run_case fail verify-trading-db.sh
  assert_contains error "No trading-db schema initializer Job found in env-azure-prod."
  case "$scenario" in
    diagnostic-one)
      assert_contains error "export APP_NAMESPACE=env-azure-prod-adaptive-apps"
      assert_contains error "bash resources/verify-trading-db.sh" ;;
    diagnostic-multiple)
      assert_contains error "env-azure-prod-adaptive-apps"
      assert_contains error "env-local-prod-adaptive-apps"
      ! grep -Fq 'export APP_NAMESPACE=' "${case_dir}/error" ||
        { echo "FAIL: ambiguous namespaces were selected automatically"; exit 1; } ;;
    diagnostic-none) assert_contains error "initialization may not have been deployed" ;;
    diagnostic-denied) assert_contains error "Could not list initializer Jobs across namespaces" ;;
    diagnostic-malformed) assert_contains error "Expected a Kubernetes Job list" ;;
  esac
  assert_read_only
done

scenario=unset-namespace
unset APP_NAMESPACE
run_case fail verify-trading-db.sh
assert_contains error "Set APP_NAMESPACE"
[[ ! -s "${case_dir}/calls" ]] ||
  { echo "FAIL: missing namespace invoked external tools"; exit 1; }

scenario=success
export APP_NAMESPACE=env-azure-prod-adaptive-apps
run_case pass verify-trading-db.sh
assert_contains output "Using latest schema initializer: fixture-schema"
assert_contains output "Database queries and backend Demo Account check passed."
assert_contains calls "kubectl delete pod fixture-verification"
! grep -Fq -- '--all-namespaces' "${case_dir}/calls" ||
  { echo "FAIL: successful verification performed cross-namespace discovery"; exit 1; }

echo "All ${cases} Trading namespace and verification checks passed."
