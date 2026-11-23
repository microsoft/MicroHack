#!/usr/bin/env bash
set -euo pipefail

if (($# < 3)); then
  echo "Usage: $0 <workspace> <environment> <resource-type>..." >&2
  exit 2
fi
workspace="$1"
environment="$2"
shift 2
recipes="$(rad recipe list --workspace "$workspace" \
  --group "${RADIUS_GROUP:-rg-trading}" --environment "$environment" --output json)"
if ! jq --exit-status --slurp 'length == 1 and (.[0] | type == "array")' <<<"$recipes" >/dev/null; then
  echo "ERROR: Expected a recipe array from ${workspace}/${environment}; cannot validate registrations." >&2
  exit 1
fi
missing=0
for resource_type in "$@"; do
  if ! jq --exit-status --arg type "$resource_type" \
    'type == "array" and any(.[]; .resourceType == $type and .name == "default"
      and .templateKind == "bicep" and (.templatePath | type == "string" and length > 0))' \
    <<<"$recipes" >/dev/null; then
    echo "WARNING: Missing usable default Bicep recipe for ${resource_type} in ${workspace}/${environment}." >&2
    missing=$((missing + 1))
  fi
done
if ((missing > 0)); then
  echo "ERROR: ${missing} expected recipe(s) missing or unusable in ${workspace}/${environment}. Register them before continuing." >&2
  exit 1
fi
echo "All $# expected default Bicep recipes are registered in ${workspace}/${environment}."
