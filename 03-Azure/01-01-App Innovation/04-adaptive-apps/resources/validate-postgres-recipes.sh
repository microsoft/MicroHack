#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECIPE_DIR="${ROOT_DIR}/iac/recipes"
SCHEMA_FILE="${RECIPE_DIR}/trading-schema.sql"
AZURE_RECIPE="${RECIPE_DIR}/postgres-azure-flex.bicep"
KUBERNETES_RECIPE="${RECIPE_DIR}/postgres-kubernetes.bicep"
SQL_RECIPE="${RECIPE_DIR}/sql-server.bicep"

for file in "$SCHEMA_FILE" "$AZURE_RECIPE" "$KUBERNETES_RECIPE" "$SQL_RECIPE"; do
  [[ -f "$file" ]] || {
    echo "Missing PostgreSQL recipe input: $file" >&2
    exit 1
  }
done

for recipe in "$AZURE_RECIPE" "$KUBERNETES_RECIPE"; do
  grep -Fq "loadTextContent('trading-schema.sql')" "$recipe" || {
    echo "$(basename "$recipe") does not consume the shared schema." >&2
    exit 1
  }
done

for table in accounts orders trades positions; do
  grep -Eq "CREATE TABLE IF NOT EXISTS ${table}[[:space:]]*\\(" "$SCHEMA_FILE" || {
    echo "Shared schema is missing table: $table" >&2
    exit 1
  }
done

grep -Fq "WHERE NOT EXISTS (" "$SCHEMA_FILE"
grep -Fq "WHERE name = 'Demo Account'" "$SCHEMA_FILE"
if grep -Fq "ON CONFLICT DO NOTHING" "$SCHEMA_FILE"; then
  echo "Demo Account must use an explicit idempotency guard." >&2
  exit 1
fi

grep -Fq "PGSSLMODE" "$AZURE_RECIPE"
grep -Fq "value: 'require'" "$AZURE_RECIPE"
if grep -Eq "0\\.0\\.0\\.0|255\\.255\\.255\\.255" "$AZURE_RECIPE"; then
  echo "Azure PostgreSQL recipe contains a broad firewall address." >&2
  exit 1
fi

if grep -REiq "postgres(-azure-flex|-kubernetes)?:latest" \
  "${ROOT_DIR}/Readme.md" "${ROOT_DIR}/iac" "${ROOT_DIR}/resources" \
  "${ROOT_DIR}/challenges" "${ROOT_DIR}/walkthrough"; then
  echo "A corrected PostgreSQL recipe still uses a mutable latest reference." >&2
  exit 1
fi

# Azure rejects tag names containing '/', so recipes that provision Azure resources must
# use the hyphenated form. Kubernetes labels keep 'radapp.io/...' and are not checked here.
for recipe in "$AZURE_RECIPE" "$SQL_RECIPE"; do
  for tag in radapp.io-environment radapp.io-resource radapp.io-application; do
    grep -Fq "'${tag}'" "$recipe" || {
      echo "$(basename "$recipe") must tag Azure resources with '${tag}'." >&2
      exit 1
    }
  done
done

# sql-server.bicep provisions only Azure resources, so any 'radapp.io/' key in it is an
# invalid Azure tag name rather than a Kubernetes label.
if grep -Fq "radapp.io/" "$SQL_RECIPE"; then
  echo "sql-server.bicep uses a 'radapp.io/' Azure tag name, which Azure rejects." >&2
  exit 1
fi

# PostgreSQL Flexible Server serializes control-plane operations, so the server's child
# resources must be chained rather than deployed in parallel or they fail with ServerIsBusy.
grep -Fq "@batchSize(1)" "$AZURE_RECIPE" || {
  echo "Azure PostgreSQL recipe must deploy firewall rules one at a time." >&2
  exit 1
}
dependency_blocks="$(grep -c "dependsOn:" "$AZURE_RECIPE" || true)"
if (( dependency_blocks < 4 )); then
  echo "Azure PostgreSQL recipe must chain the flexible server's child resources; found ${dependency_blocks} dependsOn blocks, expected at least 4." >&2
  exit 1
fi

# Radius surfaces a recipe's `values` map as the resource's properties, and a schema-declared
# `secrets` property is populated from that map. Returning `secrets` as a top-level sibling
# instead routes it into a managed Radius.Security/secrets resource, which leaves only
# `properties.secrets.name` on the resource and makes `db.properties.secrets.password`
# unresolvable in app.bicep. Keep `secrets` nested inside `values`.
for recipe in "$AZURE_RECIPE" "$KUBERNETES_RECIPE" "$SQL_RECIPE"; do
  if grep -Eq "^  secrets:" "$recipe"; then
    echo "$(basename "$recipe") declares a top-level 'secrets' output; nest it inside 'values'." >&2
    exit 1
  fi
  grep -Eq "^    secrets:" "$recipe" || {
    echo "$(basename "$recipe") must return 'secrets' nested inside the 'values' map." >&2
    exit 1
  }
done

# The Radius deployment engine resolves `references(<collection>, 'full')` to the template's
# resource metadata, which exposes 'resourceId' rather than 'id'. A `map(<collection>, r => r.id)`
# or a `<k8s-resource>.metadata.name` lookup inside `output result` therefore throws while the
# outputs are evaluated. That failure is only a warning: the deployment still reports success but
# returns no outputs, so Radius records none of the recipe's values and the resource silently
# comes back without host/port/database/username/secrets. Keep the result block reference-free.
output_block="$(sed -n '/^output result object = {/,$p' "$AZURE_RECIPE")"
if grep -Eq "map\([a-zA-Z]" <<<"$output_block"; then
  echo "Azure PostgreSQL recipe maps over a resource collection in 'output result'; build the IDs with resourceId() instead." >&2
  exit 1
fi
if grep -Fq ".metadata.name" <<<"$output_block"; then
  echo "Azure PostgreSQL recipe dereferences a Kubernetes resource in 'output result'; use the compile-time name variable instead." >&2
  exit 1
fi
grep -Fq "var firewallRuleIds = [" "$AZURE_RECIPE" || {
  echo "Azure PostgreSQL recipe must precompute firewall rule IDs with resourceId()." >&2
  exit 1
}

echo "PostgreSQL recipe parity and security assertions passed."
