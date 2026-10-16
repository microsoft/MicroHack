#!/usr/bin/env bash
set -euo pipefail
test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="${PWD}/.adaptive-console-tests-$$"
mkdir -m 700 "$work"
trap 'rm -rf -- "$work"' EXIT
export TMPDIR="$work"
: "${PWSH_COMMAND:=pwsh}"
: "${BICEP_COMMAND:=bicep}"
export BICEP_COMMAND
export ADAPTIVE_TEST_FILE="$test_dir/console.Tests.ps1"
"$PWSH_COMMAND" -NoProfile -Command '
  $ErrorActionPreference = "Stop"
  if ($env:PESTER_MODULE) { Import-Module $env:PESTER_MODULE } else { Import-Module Pester -MinimumVersion 5.0 }
  $result = Invoke-Pester -Path $env:ADAPTIVE_TEST_FILE -PassThru -Output Detailed
  if ($result.FailedCount -gt 0) { exit 1 }
'
