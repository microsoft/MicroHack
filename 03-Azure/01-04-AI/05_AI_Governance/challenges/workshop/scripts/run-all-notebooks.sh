#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workshop_dir="$(cd "$script_dir/.." && pwd)"

kernel_name="${KERNEL_NAME:-workshop}"
timeout_seconds="${TIMEOUT_SECONDS:-1200}"
allow_errors="${ALLOW_ERRORS:-true}"
python_bin="${PYTHON_BIN:-python}"

cd "$workshop_dir"

if [[ ! -d .venv ]]; then
  printf 'Expected virtual environment not found: %s/.venv\n' "$workshop_dir" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate

require_command "$python_bin"
require_command jupyter

log "Registering Jupyter kernel '$kernel_name'"
"$python_bin" -m ipykernel install --user \
  --name "$kernel_name" \
  --display-name "workshop ($("$python_bin" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'))" \
  >/dev/null

notebooks=()
while IFS= read -r -d '' notebook; do
  notebooks+=("$notebook")
done < <(find "$workshop_dir" -maxdepth 1 -type f -name '*.ipynb' -print0 | sort -z)

if [[ ${#notebooks[@]} -eq 0 ]]; then
  printf 'No notebooks found in %s\n' "$workshop_dir" >&2
  exit 1
fi

success_count=0
failure_count=0

for notebook in "${notebooks[@]}"; do
  notebook_name="$(basename "$notebook")"
  log "Executing $notebook_name"

  if "$python_bin" -m jupyter nbconvert \
    --to notebook \
    --execute \
    --inplace \
    --ExecutePreprocessor.kernel_name="$kernel_name" \
    --ExecutePreprocessor.timeout="$timeout_seconds" \
    --ExecutePreprocessor.allow_errors="$allow_errors" \
    "$notebook"; then
    printf 'Completed: %s\n' "$notebook_name"
    success_count=$((success_count + 1))
    continue
  fi

  printf 'Failed: %s\n' "$notebook_name" >&2
  failure_count=$((failure_count + 1))

  if [[ "$allow_errors" != "true" ]]; then
    break
  fi
done

printf '\nSummary: %d completed, %d failed\n' "$success_count" "$failure_count"

if (( failure_count > 0 )); then
  exit 1
fi
