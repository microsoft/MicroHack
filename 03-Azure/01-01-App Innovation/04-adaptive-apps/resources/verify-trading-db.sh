#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root.
set -euo pipefail

: "${APP_NAMESPACE:?Set APP_NAMESPACE to the deployed application namespace.}"
for command_name in kubectl jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

pod_name=""
cleanup() {
  if [[ -n "$pod_name" ]]; then
    kubectl delete pod "$pod_name" --namespace "$APP_NAMESPACE" \
      --ignore-not-found --wait=false || {
      echo "Could not delete verification pod ${pod_name}; remove it manually." >&2
      return 1
    }
  fi
}
trap cleanup EXIT

echo "Kubernetes context: $(kubectl config current-context)"
echo "Application namespace: ${APP_NAMESPACE}"

jobs="$(kubectl get jobs --namespace "$APP_NAMESPACE" \
  --selector app=postgres-schema-initializer,resource=trading-db \
  --ignore-not-found --output json)" || {
  echo "Could not inspect initializer Jobs in ${APP_NAMESPACE}; check namespace access." >&2
  exit 1
}
schema_job=""
if [[ -n "$jobs" ]]; then
  jq -e 'type == "object" and (.items | type == "array")' <<<"$jobs" >/dev/null || {
    echo "Expected a Kubernetes Job list for ${APP_NAMESPACE}." >&2
    exit 1
  }
  schema_job="$(jq -r '.items | sort_by(.metadata.creationTimestamp) |
    last | .metadata.name // empty' <<<"$jobs")"
fi
[[ -n "$schema_job" ]] || {
  echo "No trading-db schema initializer Job found in ${APP_NAMESPACE}." >&2
  other_jobs="$(kubectl get jobs --all-namespaces \
    --selector app=postgres-schema-initializer,resource=trading-db --output json)" || {
    echo "Could not list initializer Jobs across namespaces; check permissions and the Kubernetes context." >&2
    exit 1
  }
  namespaces="$(jq -r '
    if type == "object" and (.items | type == "array") and
      all(.items[]; .metadata.namespace | type == "string" and length > 0)
    then .items | map(.metadata.namespace) | unique[]
    else error("Expected a Kubernetes Job list with namespace metadata")
    end
  ' <<<"$other_jobs")" || {
    echo "Could not determine the namespaces containing initializer Jobs." >&2
    exit 1
  }
  if [[ -z "$namespaces" ]]; then
    echo "No matching Job exists in this Kubernetes context; initialization may not have been deployed." >&2
  else
    mapfile -t matching_namespaces <<<"$namespaces"
    echo "Found matching initializer Jobs in:" >&2
    printf '  %s\n' "${matching_namespaces[@]}" >&2
    if ((${#matching_namespaces[@]} == 1)); then
      echo "To verify that application, run:" >&2
      printf '  export APP_NAMESPACE=%q\n' "${matching_namespaces[0]}" >&2
      echo "  bash resources/verify-trading-db.sh" >&2
    else
      echo "Select the intended application namespace explicitly; verification will not choose one." >&2
    fi
  fi
  exit 1
}
echo "Using latest schema initializer: ${schema_job}"
if ! kubectl wait --namespace "$APP_NAMESPACE" --for=condition=complete \
  "job/${schema_job}" --timeout=15m; then
  kubectl logs --namespace "$APP_NAMESPACE" "job/${schema_job}" || {
    echo "Could not retrieve schema initializer logs." >&2
  }
  exit 1
fi

db_env="$(kubectl get job "$schema_job" --namespace "$APP_NAMESPACE" --output json |
  jq '.spec.template.spec.containers[0].env |
    map(select(.name == "PGHOST" or .name == "PGDATABASE" or .name == "PGUSER"
      or .name == "PGPASSWORD" or .name == "PGSSLMODE")) |
    if any(.[]; .name == "PGSSLMODE") then .
    else . + [{name: "PGSSLMODE", value: "prefer"}] end')"
jq -e '
  . as $env |
  all(["PGHOST", "PGDATABASE", "PGUSER", "PGSSLMODE"][];
    . as $name | any($env[]; .name == $name and
      (.value | type == "string" and length > 0))) and
  any(.[]; .name == "PGPASSWORD" and
    (.valueFrom.secretKeyRef.name | type == "string" and length > 0) and
    (.valueFrom.secretKeyRef.key | type == "string" and length > 0))
' <<<"$db_env" >/dev/null || {
  echo "Schema Job is missing database connection settings or its password Secret reference." >&2
  exit 1
}
jq -r '
  .[] | select(.name == "PGHOST" or .name == "PGDATABASE" or .name == "PGSSLMODE") |
  "\(.name)=\(.value)"
' <<<"$db_env"

kubectl wait --namespace "$APP_NAMESPACE" --for=condition=Available \
  deployment/backend --timeout=5m

sql_script="$(cat <<'SQL_SCRIPT'
psql --set=ON_ERROR_STOP=1 <<'SQL'
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('accounts', 'orders', 'trades', 'positions')
ORDER BY table_name;

SELECT 'demo_seed_count=' || count(*)
FROM accounts
WHERE name = 'Demo Account';

SELECT id, account_id, symbol, side, quantity, price, status, created_at
FROM orders
ORDER BY id DESC
LIMIT 20;
SQL
SQL_SCRIPT
)"
backend_script="$(cat <<'BACKEND_SCRIPT'
accounts="$(curl --silent --show-error --fail --connect-timeout 10 --max-time 60 \
  http://backend:8080/api/accounts)"
printf '%s\n' "$accounts" | grep -F '"Demo Account"'
BACKEND_SCRIPT
)"

pod_name="$(jq -n --arg namespace "$APP_NAMESPACE" --argjson env "$db_env" \
  --arg sql "$sql_script" --arg backend "$backend_script" '{
    apiVersion: "v1",
    kind: "Pod",
    metadata: {generateName: "trading-db-verify-", namespace: $namespace},
    spec: {
      restartPolicy: "Never",
      activeDeadlineSeconds: 300,
      containers: [
        {name: "psql", image: "postgres:16-alpine",
          command: ["sh", "-ceu", $sql], env: $env},
        {name: "backend-check", image: "curlimages/curl:8.12.1",
          command: ["sh", "-ceu", $backend]}
      ]
    }
  }' | kubectl create -f - --output jsonpath='{.metadata.name}')"

echo "Verification pod: ${pod_name}"
for ((attempt = 0; attempt < 150; attempt++)); do
  phase="$(kubectl get pod "$pod_name" --namespace "$APP_NAMESPACE" \
    --output jsonpath='{.status.phase}')"
  case "$phase" in
    Succeeded | Failed) break ;;
  esac
  sleep 2
done

if [[ "$phase" != "Succeeded" ]]; then
  echo "Verification did not succeed (pod phase: ${phase})." >&2
  kubectl describe pod "$pod_name" --namespace "$APP_NAMESPACE" || {
    echo "Could not describe verification pod." >&2
  }
fi
for container in psql backend-check; do
  echo "=== ${container} ==="
  kubectl logs "$pod_name" --namespace "$APP_NAMESPACE" --container "$container" || {
    echo "Could not retrieve ${container} logs." >&2
    exit 1
  }
done
[[ "$phase" == "Succeeded" ]] || exit 1
echo "Database queries and backend Demo Account check passed."
