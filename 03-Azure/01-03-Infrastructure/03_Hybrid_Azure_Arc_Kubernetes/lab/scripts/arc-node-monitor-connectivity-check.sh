#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Synopsis: Azure Arc NODE Monitoring Connectivity Validation Script
#           (Public Mode, v3 — region-aware, instance-aware)
#
# Purpose:
#   Validate outbound DNS/TLS/HTTPS from inside the Kubernetes cluster to
#   the Azure Monitor endpoints used by:
#     • Container Insights (logs via Data Collection Endpoints / workspace)
#     • Managed Prometheus (metrics via DCE)
#   in PUBLIC (non–Private Link / non–AMPLS) mode.
#
# Why v3:
#   Earlier versions probed base/wildcard hosts that do not exist in DNS
#   (e.g., "ingest.monitor.azure.com", "ods.opinsights.azure.com",
#   "blob.core.windows.net") and produced false failures. v3 only checks
#   globally resolvable endpoints by default and lets you specify your real
#   ingestion/workspace/blob FQDNs explicitly.
#
# What is always checked (public mode):
#   ✔ Global + regional control handlers:
#       - global.handler.control.monitor.azure.com
#       - <region>.handler.control.monitor.azure.com
#   ✔ Authentication & telemetry:
#       - login.microsoftonline.com
#       - dc.services.visualstudio.com
#   ✔ Extension container images:
#       - mcr.microsoft.com
#
# What you can additionally validate (your real FQDNs):
#   • Logs DCE:   dce-<guid>.<region>.ingest.monitor.azure.com
#   • Metrics DCE: dce-<guid>.<region>.metrics.ingest.monitor.azure.com
#   • Workspace ingestion:
#       <workspaceId>.ods.opinsights.azure.com
#     (optional legacy)
#       <workspaceId>.oms.opinsights.azure.com
#   • Blob storage account used by agents/extensions:
#       <account>.blob.core.windows.net
#
# Flags (all optional — supply the actual hostnames for your environment):
#   --dce-logs     <fqdn>   e.g., dce-1234...abcd.westeurope.ingest.monitor.azure.com
#   --dce-metrics  <fqdn>   e.g., dce-5678...ef90.westeurope.metrics.ingest.monitor.azure.com
#   --ods-host     <fqdn>   e.g., 1234...abcd.ods.opinsights.azure.com
#   --oms-host     <fqdn>   e.g., 1234...abcd.oms.opinsights.azure.com
#   --blob-account <fqdn>   e.g., mystorageacct.blob.core.windows.net
#
# Usage:
#   # Minimal (global/region control, AAD, telemetry, MCR):
#   ./arc-node-monitoring-check_v3.sh westeurope
#
#   # Full run with real endpoints (replace with your FQDNs):
#   ./arc-node-monitoring-check_v3.sh westeurope \
#     --dce-logs dce-12345678-90ab-cdef-1234-567890abcdef.westeurope.ingest.monitor.azure.com \
#     --dce-metrics dce-22345678-90ab-cdef-1234-567890abcdef.westeurope.metrics.ingest.monitor.azure.com \
#     --ods-host 12345678-90ab-cdef-1234-567890abcdef.ods.opinsights.azure.com \
#     --blob-account mystorageacct.blob.core.windows.net
#
# How to discover your FQDNs (from a client with Azure CLI):
#   az monitor data-collection endpoint list -g <rg> -o table
#   az monitor data-collection rule list -g <rg> -o table
#   # Copy the ingestion URLs and workspace hostnames into the flags above.
#
# Output & Exit Codes:
#   • Prints DNS/TLS/HTTPS results per endpoint and a summary.
#   • exit 0 → all tested endpoints OK
#   • exit 1 → one or more tested endpoints failed
#
# Requirements inside the pod:
#   curl, dnsutils (or nslookup/getent), openssl, ca-certificates.
#
# References (public mode firewall guidance):
#   - Network firewall requirements for monitoring Kubernetes clusters
#   - Outbound network & FQDN rules for AKS (Azure Monitor section)
# ------------------------------------------------------------------------------

REGION_RAW="${1:-westeurope}"
shift || true

# Optional flags: pass actual endpoint FQDNs
DCE_LOGS_FQDN=""
DCE_METRICS_FQDN=""
ODS_FQDN=""
OMS_FQDN=""
BLOB_ACCOUNT_FQDN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dce-logs)       DCE_LOGS_FQDN="${2:-}"; shift 2 ;;
    --dce-metrics)    DCE_METRICS_FQDN="${2:-}"; shift 2 ;;
    --ods-host)       ODS_FQDN="${2:-}"; shift 2 ;;
    --oms-host)       OMS_FQDN="${2:-}"; shift 2 ;;
    --blob-account)   BLOB_ACCOUNT_FQDN="${2:-}"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 2 ;;
  esac
done

# Normalize region to Azure FQDN segment
REGION="$(echo "$REGION_RAW" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"

CURL_TIMEOUT=7
OPENSSL_TIMEOUT=7

COLOR_OK="\033[32m"
COLOR_ERR="\033[31m"
COLOR_WARN="\033[33m"
COLOR_DIM="\033[90m"
COLOR_RESET="\033[0m"

h1(){ echo -e "\n\033[1m$1\033[0m"; }
ok(){ echo -e "${COLOR_OK}✔${COLOR_RESET} $1"; }
err(){ echo -e "${COLOR_ERR}✖${COLOR_RESET} $1"; }
warn(){ echo -e "${COLOR_WARN}⚠${COLOR_RESET} $1"; }

# DNS resolver selection
RESOLVER_CMD=""
if command -v dig >/dev/null 2>&1; then
  RESOLVER_CMD="dig +short"
elif command -v nslookup >/dev/null 2>&1; then
  RESOLVER_CMD="nslookup"
elif command -v getent >/dev/null 2>&1; then
  RESOLVER_CMD="getent hosts"
else
  echo "Need dig/nslookup/getent installed"; exit 2
fi

# Always-available endpoints in public mode
CONTROL_ENDPOINTS=(
  "global.handler.control.monitor.azure.com"
  "${REGION}.handler.control.monitor.azure.com"
)
AUX_ENDPOINTS=(
  "login.microsoftonline.com"
  "dc.services.visualstudio.com"
)
ARTIFACT_ENDPOINTS=(
  "mcr.microsoft.com"
)

# Optional environment-specific endpoints (only if provided)
OPTIONAL_ENDPOINTS=()
[[ -n "$DCE_LOGS_FQDN"    ]] && OPTIONAL_ENDPOINTS+=("$DCE_LOGS_FQDN")
[[ -n "$DCE_METRICS_FQDN" ]] && OPTIONAL_ENDPOINTS+=("$DCE_METRICS_FQDN")
[[ -n "$ODS_FQDN"         ]] && OPTIONAL_ENDPOINTS+=("$ODS_FQDN")
[[ -n "$OMS_FQDN"         ]] && OPTIONAL_ENDPOINTS+=("$OMS_FQDN")
[[ -n "$BLOB_ACCOUNT_FQDN" ]] && OPTIONAL_ENDPOINTS+=("$BLOB_ACCOUNT_FQDN")

ALL_ENDPOINTS=(
  "${CONTROL_ENDPOINTS[@]}"
  "${AUX_ENDPOINTS[@]}"
  "${ARTIFACT_ENDPOINTS[@]}"
  "${OPTIONAL_ENDPOINTS[@]}"
)

PASSED=()
FAILED=()
SKIPPED=()

dns_check(){
  local host="$1"
  if [[ "$RESOLVER_CMD" == "dig +short" ]]; then
    dig +short "$host" | grep -E '^[0-9a-fA-F:.]+$' >/dev/null \
      && ok "DNS resolves: $host" || { err "DNS failed: $host"; return 1; }
  elif [[ "$RESOLVER_CMD" == "nslookup" ]]; then
    nslookup "$host" >/dev/null 2>&1 \
      && ok "DNS resolves: $host" || { err "DNS failed: $host"; return 1; }
  else
    getent hosts "$host" >/dev/null 2>&1 \
      && ok "DNS resolves: $host" || { err "DNS failed: $host"; return 1; }
  fi
}

tls_check(){
  local host="$1"
  timeout "$OPENSSL_TIMEOUT" bash -c "echo | openssl s_client -servername ${host} -connect ${host}:443 >/dev/null 2>&1" \
    && ok "TLS OK: ${host}:443" || { err "TLS FAILED: ${host}:443"; return 1; }
}

https_check(){
  local host="$1"
  curl -sS -I --connect-timeout "$CURL_TIMEOUT" "https://${host}" >/dev/null 2>&1 \
    && ok "HTTPS OK: https://${host}" || { err "HTTPS FAILED: https://${host}"; return 1; }
}

h1 "Azure Arc NODE Monitoring Connectivity Check (Public Mode, v3) — region: ${REGION}"
[[ -n "${HTTPS_PROXY:-}" || -n "${HTTP_PROXY:-}" ]] && echo -e "${COLOR_DIM}Proxy: HTTPS_PROXY=${HTTPS_PROXY:-<unset>} HTTP_PROXY=${HTTP_PROXY:-<unset>}${COLOR_RESET}"

# Inform about skipped environment-specific checks
if [[ -z "$DCE_LOGS_FQDN" || -z "$DCE_METRICS_FQDN" || -z "$ODS_FQDN" || -z "$BLOB_ACCOUNT_FQDN" ]]; then
  h1 "Note on environment-specific endpoints (skipped unless provided)"
  [[ -z "$DCE_LOGS_FQDN"    ]] && { warn "Skipping Logs DCE (use --dce-logs <fqdn>)"; SKIPPED+=("DCE_LOGS"); }
  [[ -z "$DCE_METRICS_FQDN" ]] && { warn "Skipping Metrics DCE (use --dce-metrics <fqdn>)"; SKIPPED+=("DCE_METRICS"); }
  [[ -z "$ODS_FQDN"         ]] && { warn "Skipping Workspace ingestion (use --ods-host <fqdn> / --oms-host <fqdn>)"; SKIPPED+=("ODS/OMS"); }
  [[ -z "$BLOB_ACCOUNT_FQDN" ]] && { warn "Skipping Blob account check (use --blob-account <account>.blob.core.windows.net)"; SKIPPED+=("BLOB"); }
fi

h1 "1) DNS"
for host in "${ALL_ENDPOINTS[@]}"; do
  dns_check "$host" && PASSED+=("DNS:$host") || FAILED+=("DNS:$host")
done

h1 "2) TLS Handshake (443)"
for host in "${ALL_ENDPOINTS[@]}"; do
  tls_check "$host" && PASSED+=("TLS:$host") || FAILED+=("TLS:$host")
done

h1 "3) HTTPS Reachability (443)"
for host in "${ALL_ENDPOINTS[@]}"; do
  https_check "$host" && PASSED+=("HTTPS:$host") || FAILED+=("HTTPS:$host")
done

h1 "Summary"
echo -e "Passed: ${COLOR_OK}${#PASSED[@]}${COLOR_RESET} | Failed: ${COLOR_ERR}${#FAILED[@]}${COLOR_RESET} | Skipped: ${COLOR_WARN}${#SKIPPED[@]}${COLOR_RESET}"

if (( ${#FAILED[@]} > 0 )); then
  echo -e "${COLOR_ERR}Failures:${COLOR_RESET}"
  for f in "${FAILED[@]}"; do echo " - $f"; done
  echo -e "\nTroubleshooting Hints:"
  echo " - Allow outbound HTTPS (443) to your DCE hosts (logs & metrics) and workspace ingestion FQDNs."
  echo " - Allow global and regional handler.control endpoints."
  echo " - Disable TLS inspection; agents expect end-to-end TLS."
  echo " - Ensure mcr.microsoft.com and your Blob account are reachable for extension artifacts."
  exit 1
else
  echo -e "${COLOR_OK}All required checks passed for the endpoints tested.${COLOR_RESET}"
  if (( ${#SKIPPED[@]} > 0 )); then
    echo -e "${COLOR_WARN}Note: ${#SKIPPED[@]} environment-specific checks were skipped. Supply flags to validate them.${COLOR_RESET}"
  fi
  exit 0
fi