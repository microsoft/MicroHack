#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <workspace> <environment>" >&2
  exit 2
fi
for command_name in rad kubectl jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

workspace="$1"
environment="$2"
environment_namespace="$(rad env show "$environment" --workspace "$workspace" \
  --group "${RADIUS_GROUP:-rg-trading}" --output json |
  jq -er '.properties.compute.namespace | select(type == "string" and length > 0)')" || {
  echo "Could not read the compute namespace for ${workspace}/${environment}." >&2
  exit 1
}

matches=()
for candidate in "${environment_namespace}-adaptive-apps" "$environment_namespace"; do
  jobs="$(kubectl get jobs --namespace "$candidate" \
    --selector app=postgres-schema-initializer,resource=trading-db \
    --ignore-not-found --output json)" || {
    echo "Could not inspect initializer Jobs in ${candidate}; check namespace access." >&2
    exit 1
  }
  # --ignore-not-found may return no output when the namespace does not exist.
  [[ -n "$jobs" ]] || continue
  jq -e 'type == "object" and (.items | type == "array")' <<<"$jobs" >/dev/null || {
    echo "Expected a Kubernetes Job list for ${candidate}." >&2
    exit 1
  }
  if jq -e '.items | length > 0' <<<"$jobs" >/dev/null; then
    matches+=("$candidate")
  fi
done

case "${#matches[@]}" in
  1) printf '%s\n' "${matches[0]}" ;;
  0)
    echo "No trading-db initializer Job found in either ${environment_namespace}-adaptive-apps or ${environment_namespace}." >&2
    echo "Check the Kubernetes context and recipe deployment before continuing." >&2
    exit 1
    ;;
  *)
    echo "Trading initializer Jobs exist in multiple candidate namespaces:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    echo "Select the intended application namespace explicitly; discovery will not choose one." >&2
    exit 1
    ;;
esac
