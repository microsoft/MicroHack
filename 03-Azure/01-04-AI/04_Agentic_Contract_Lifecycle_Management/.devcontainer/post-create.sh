#!/usr/bin/env bash
# =============================================================================
# Dev container post-create hook (runs once after the container is built).
#
#   1. Install the Python dependencies (src/requirements.txt) — ESSENTIAL:
#      every challenge needs these.
#   2. Best-effort install of the Microsoft ODBC Driver 18 for SQL Server so the
#      OPTIONAL Azure SQL contract-status / renewal tool works out of the box.
#      That tool's connection string uses "Driver={ODBC Driver 18 for SQL
#      Server}" (see labautomation/infra/resources.bicep), so unixODBC alone is
#      not enough. If this step fails (e.g. no network to packages.microsoft.com)
#      the tool simply falls back to the bundled JSON corpus, so we NEVER fail
#      the whole container build over an optional driver.
# =============================================================================
set -euo pipefail

echo "==> [1/2] Installing Python dependencies (src/requirements.txt)"
pip install --upgrade pip
pip install -r src/requirements.txt

echo "==> [2/2] Installing Microsoft ODBC Driver 18 for SQL Server (optional Azure SQL tool)"
if command -v odbcinst >/dev/null 2>&1 && odbcinst -q -d 2>/dev/null | grep -q "ODBC Driver 18 for SQL Server"; then
  echo "    Driver already present — skipping."
else
  # Debian 12 (bookworm) — matches the python:3.11-bookworm base image.
  if (
    set -e
    curl -sSL -O https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm -f packages-microsoft-prod.deb
    sudo apt-get update
    sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18
  ); then
    echo "    ODBC Driver 18 installed."
  else
    echo "    WARN: msodbcsql18 install failed — the Azure SQL tool will use the JSON fallback."
  fi
fi

echo "==> post-create complete."
