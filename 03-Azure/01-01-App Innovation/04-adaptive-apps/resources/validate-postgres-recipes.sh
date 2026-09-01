#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECIPE_DIR="${ROOT_DIR}/iac/recipes"
SCHEMA_FILE="${RECIPE_DIR}/trading-schema.sql"
AZURE_RECIPE="${RECIPE_DIR}/postgres-azure-flex.bicep"
KUBERNETES_RECIPE="${RECIPE_DIR}/postgres-kubernetes.bicep"
SQL_RECIPE="${RECIPE_DIR}/sql-server.bicep"
APP_TEMPLATE="${ROOT_DIR}/iac/app.bicep"

for file in "$SCHEMA_FILE" "$AZURE_RECIPE" "$KUBERNETES_RECIPE" "$SQL_RECIPE" "$APP_TEMPLATE"; do
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

# Radius treats `secrets` as a framework-owned property (pkg/resourceutil.BasicProperties). A
# `secrets` map nested inside `values` is discarded by the recipe-output copier, and a top-level
# `secrets` object is instead materialized into a managed Radius.Security/secrets resource that is
# surfaced only through a reserved `secrets.name` sub-property these resource types do not declare.
# Either shape leaves `properties.secrets.password` unresolvable, so the PostgreSQL recipes must not
# return the password as a recipe value at all; consumers bind the credentials Secret by name.
#
# The Radius deployment engine also resolves `references(<collection>, 'full')` to the template's
# resource metadata, which exposes 'resourceId' rather than 'id'. A `map(<collection>, r => r.id)`
# or a `<k8s-resource>.metadata.name` lookup inside `output result` therefore throws while the
# outputs are evaluated. That failure is only a warning: the deployment still reports success but
# returns no outputs, so Radius records none of the recipe's values and the resource silently comes
# back without host/port/database/username. Keep the result block reference-free.
for recipe in "$AZURE_RECIPE" "$KUBERNETES_RECIPE"; do
  output_block="$(sed -n '/^output result object = {/,$p' "$recipe")"
  if grep -Eq "^[[:space:]]*secrets:" <<<"$output_block"; then
    echo "$(basename "$recipe") returns 'secrets' from the recipe result, which Radius never surfaces as properties.secrets.password." >&2
    exit 1
  fi
  if grep -Eq "map\([a-zA-Z]" <<<"$output_block"; then
    echo "$(basename "$recipe") maps over a resource collection in 'output result'; build the IDs with resourceId() instead." >&2
    exit 1
  fi
  if grep -Fq ".metadata.name" <<<"$output_block"; then
    echo "$(basename "$recipe") dereferences a Kubernetes resource in 'output result'; use the compile-time name variable instead." >&2
    exit 1
  fi
done

# Both PostgreSQL recipes must name their credentials Secret deterministically from the Radius
# resource name so that the shared application template can bind it in either environment.
for recipe in "$AZURE_RECIPE" "$KUBERNETES_RECIPE"; do
  grep -Fq "context.resource.name}-credentials" "$recipe" || {
    echo "$(basename "$recipe") must name its credentials Secret '<resource-name>-credentials'." >&2
    exit 1
  }
done

# The application template must consume that Secret rather than a property Radius never populates.
if grep -v '^[[:space:]]*//' "$APP_TEMPLATE" | grep -Fq "properties.secrets.password"; then
  echo "app.bicep reads properties.secrets.password, which Radius never populates." >&2
  exit 1
fi
grep -Fq "tradingDbName}-credentials" "$APP_TEMPLATE" || {
  echo "app.bicep must bind the database password from the recipe's credentials Secret." >&2
  exit 1
}
grep -Fq "secretRef:" "$APP_TEMPLATE" || {
  echo "app.bicep must inject the database password with valueFrom.secretRef." >&2
  exit 1
}
# Deriving the Secret name from `tradingDb.name` compiles to a runtime `reference('tradingDb').name`
# call, and the resource's property bag does not expose `name`. Keep the name compile-time.
if grep -v '^[[:space:]]*//' "$APP_TEMPLATE" | grep -Fq 'tradingDb.name'; then
  echo "app.bicep derives a name from tradingDb.name, which compiles to an unresolvable runtime reference()." >&2
  exit 1
fi
grep -Fq "var firewallRuleIds = [" "$AZURE_RECIPE" || {
  echo "Azure PostgreSQL recipe must precompute firewall rule IDs with resourceId()." >&2
  exit 1
}

echo "PostgreSQL recipe parity and security assertions passed."
