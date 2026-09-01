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

echo "PostgreSQL recipe parity and security assertions passed."
