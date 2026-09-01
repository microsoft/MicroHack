#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${HOME}/venvs/amlcosmos"

if [[ -z "${COSMOS_ENDPOINT:-}" ]]; then
    if [[ -z "${1:-}" ]]; then
        echo "Usage: $0 <cosmos-account-name>" >&2
        echo "Alternatively, set COSMOS_ENDPOINT before running this script." >&2
        exit 1
    fi
    export COSMOS_ENDPOINT="https://${1}.documents.azure.com:443/"
fi

export COSMOS_DATABASE="${COSMOS_DATABASE:-aml}"

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
trap 'deactivate 2>/dev/null || true' EXIT

python -m pip install -r "$SCRIPT_DIR/src/requirements-cosmos.txt"

python "$SCRIPT_DIR/src/cosmos_load.py" import \
    --endpoint "$COSMOS_ENDPOINT" \
    --database "$COSMOS_DATABASE" \
    --input "$SCRIPT_DIR/cosmos_exports/aml" \
    --create-containers

deactivate
trap - EXIT