#!/usr/bin/env bash
# ==========================================================================
# Challenge 1 (coach/setup) — create the Microsoft Entra app registration the
# SharePoint corpus needs, grant Graph permissions, admin-consent, and mint a
# client secret. Prints the SHAREPOINT_* values to paste into your repo-root .env.
#
# Grants (application / app-only, admin-consented):
#   - Sites.ReadWrite.All  → lets src/scripts/upload_corpus_to_sharepoint.py upload
#                            the PDFs (and covers the indexer's site read).
#   - Files.Read.All       → lets the AI Search SharePoint indexer read content.
#
# Requirements:
#   - Azure CLI (`az`) installed and logged in (`az login` / `--use-device-code`).
#   - Rights to create app registrations AND grant admin consent (Global Admin /
#     Privileged Role Admin / Application Administrator). If you lack consent
#     rights, the script still creates everything and tells you the one command
#     an admin must run — or follow the manual portal steps in the Ch1 README.
#
# Usage:  bash src/scripts/setup_sharepoint_app.sh ["Display Name"]
# ==========================================================================
set -euo pipefail

DISPLAY_NAME="${1:-CLM Microhack Corpus}"
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"   # Microsoft Graph

command -v az >/dev/null 2>&1 || { echo "ERROR: Azure CLI (az) not found. Install it, then run 'az login'."; exit 1; }
az account show >/dev/null 2>&1 || { echo "ERROR: not logged in. Run 'az login' (or 'az login --use-device-code') first."; exit 1; }

echo "Resolving Microsoft Graph application-role ids..."
SITES_RW=$(az ad sp show --id "$GRAPH_APP_ID" --query "appRoles[?value=='Sites.ReadWrite.All'].id | [0]" -o tsv)
FILES_READ=$(az ad sp show --id "$GRAPH_APP_ID" --query "appRoles[?value=='Files.Read.All'].id | [0]" -o tsv)
[ -n "$SITES_RW" ] && [ -n "$FILES_READ" ] || { echo "ERROR: could not resolve Graph app-role ids."; exit 1; }

# Reuse an existing app of the same name so re-runs don't create duplicates.
APP_ID=$(az ad app list --display-name "$DISPLAY_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)
if [ -z "${APP_ID:-}" ] || [ "$APP_ID" = "None" ]; then
  echo "Creating app registration '$DISPLAY_NAME'..."
  APP_ID=$(az ad app create --display-name "$DISPLAY_NAME" --sign-in-audience AzureADMyOrg --query appId -o tsv)
else
  echo "Reusing existing app registration '$DISPLAY_NAME' ($APP_ID)."
fi

# Ensure a service principal exists for the app.
az ad sp show --id "$APP_ID" >/dev/null 2>&1 || az ad sp create --id "$APP_ID" >/dev/null

echo "Adding Graph application permissions (Sites.ReadWrite.All, Files.Read.All)..."
az ad app permission add --id "$APP_ID" --api "$GRAPH_APP_ID" \
  --api-permissions "${SITES_RW}=Role" "${FILES_READ}=Role" >/dev/null

echo "Granting admin consent (requires admin rights; retrying briefly for propagation)..."
sleep 15
set +e
az ad app permission admin-consent --id "$APP_ID"
CONSENT_RC=$?
set -e
if [ "$CONSENT_RC" -ne 0 ]; then
  echo ""
  echo "WARNING: admin consent did not complete (you may lack the required rights)."
  echo "         Ask a tenant admin to run:"
  echo "           az ad app permission admin-consent --id $APP_ID"
  echo "         ...or in the portal: Entra admin center -> App registrations -> '$DISPLAY_NAME'"
  echo "         -> API permissions -> 'Grant admin consent'."
fi

echo "Creating a client secret (valid 1 year)..."
SECRET=$(az ad app credential reset --id "$APP_ID" --display-name "clm-microhack" --years 1 --query password -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

cat <<EOF

======================================================================
 App registration ready. Add these to your repo-root .env:
======================================================================
SHAREPOINT_TENANT_ID=$TENANT_ID
SHAREPOINT_APP_ID=$APP_ID
SHAREPOINT_APP_SECRET=$SECRET
----------------------------------------------------------------------
 Then set these from your SharePoint site (create the site+library first):
   SHAREPOINT_SITE_URL=https://<tenant>.sharepoint.com/sites/<YourSite>
   SHAREPOINT_DOC_LIBRARY=Documents
======================================================================
 NOTE: the client secret above is shown ONCE — copy it now.
 Next: python src/scripts/upload_corpus_to_sharepoint.py  (then seed_corpus.py)
EOF
