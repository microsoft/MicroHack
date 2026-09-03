#!/usr/bin/env bash

set -euo pipefail

WALKTHROUGH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

find "$WALKTHROUGH_DIR" -type f -name '*.sh' -exec chmod u+x {} +

echo "Shell scripts under $WALKTHROUGH_DIR are ready to run."