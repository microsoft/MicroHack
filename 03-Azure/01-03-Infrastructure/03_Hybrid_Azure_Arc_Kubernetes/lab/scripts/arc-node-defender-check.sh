#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Synopsis: Azure Arc NODE Connectivity Check for Defender for Containers
#           (Public Mode — Programmatic Enablement Requirements)
#
# This script validates *only* the additional network connectivity required
# to onboard and operate **Defender for Containers** on **Arc-enabled 
# Kubernetes clusters** when enabling the extension programmatically.
#
# The checks below are based on the official Defender for Cloud documentation:
# https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-arc-enable-programmatically
#
# Purpose:
#   Validate the outbound DNS/TLS/HTTPS connectivity from inside a Kubernetes
#   cluster to the endpoints used by Defender for Containers for:
#     - Microsoft Defender for Cloud backplane services
#     - Vulnerability assessment ingestion APIs
#     - Microsoft Container Registry for extension images
#     - Azure Storage for artifact downloads
#
# What this script checks:
#   ✔ Defender for Cloud backend:
#       - *.securitycenter.azure.com
#       - management.azure.com (ARM calls for onboarding)
#   ✔ Defender agent + Arc extension image registry:
#       - mcr.microsoft.com
#       - *.data.mcr.microsoft.com
#   ✔ Vulnerability assessment ingestion:
#       - *.prod.securitycenter.windows.com
#       - *.vulnerability.assessment.azure.com
#   ✔ Azure Storage for Defender artifacts:
#       - *.blob.core.windows.net
#
# What this script does NOT check:
#   ✘ Azure Monitor / Container Insights endpoints
#   ✘ Arc core agent / GitOps / Policy endpoints
#   ✘ Cluster Connect (Service Bus)
#   ✘ AMPLS / Private Link endpoints
#
# How to run from inside your Kubernetes cluster:
#
# 1. Start a diagnostic pod:
#      kubectl run arccheck \
#        --image=ubuntu:22.04 -it --restart=Never -- bash
#
# 2. Install required tools:
#      apt update
#      apt install -y curl dnsutils openssl ca-certificates
#
# 3. Copy or curl the script into the pod:
#      curl -sSL -o arc-node-defender-check.sh <RAW_GITHUB_URL>
#
# 4. Make it executable:
#      chmod +x arc-node-defender-check.sh
#
# 5. Run:
#      ./arc-node-defender-check.sh
#
# Output:
#   - DNS, TLS, and HTTPS validation per endpoint
#   - Summary with PASS / FAIL status
#   - Troubleshooting hints for network teams
#
# Exit Codes:
#   - 0 = all required Defender endpoints reachable
#   - 1 = one or more endpoints unreachable
#
# ------------------------------------------------------------------------------

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

# Determine DNS resolver
RESOLVER_CMD=""
if command -v dig >/dev/null 2>&1; then RESOLVER_CMD="dig +short"
elif command -v nslookup >/dev/null 2>&1; then RESOLVER_CMD="nslookup"
elif command -v getent >/dev/null 2>&1; then RESOLVER_CMD="getent hosts"
else echo "ERROR: Install dig/nslookup/getent"; exit 2; fi

# ------------------------------------------------------------------------------
# Defender for Containers Required Endpoints (Public Cloud)
# ------------------------------------------------------------------------------

DEFENDER_ENDPOINTS=(
  # ARM API for onboarding Defender extension
  "management.azure.com"

  # Defender for Cloud backend
  "securitycenter.azure.com"
  "*.securitycenter.azure.com"
  "*.prod.securitycenter.windows.com"
  "*.vulnerability.assessment.azure.com"

  # MCR (image pulls for Defender extension)
  "mcr.microsoft.com"
  "*.data.mcr.microsoft.com"

  # Azure Storage (artifact downloads)
  "*.blob.core.windows.net"
)

PASSED=()
FAILED=()

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------

dns_check(){
  local host="$1"
  [[ "$host" == *"*"* ]] && host="${host#*.}"  # strip wildcard for DNS test

  if [[ "$RESOLVER_CMD" == "dig +short" ]]; then
    dig +short "$host" | grep -E '^[0-9a-fA-F:.]+$' >/dev/null \
      && ok "DNS resolves: $host" \
      || { err "DNS failed: $host"; return 1; }
  elif [[ "$RESOLVER_CMD" == "nslookup" ]]; then
    nslookup "$host" >/dev/null 2>&1 \
      && ok "DNS resolves: $host" \
      || { err "DNS failed: $host"; return 1; }
  else
    getent hosts "$host" >/dev/null 2>&1 \
      && ok "DNS resolves: $host" \
      || { err "DNS failed: $host"; return 1; }
  fi
}

tls_check(){
  local host="$1"
  [[ "$host" == *"*"* ]] && host="${host#*.}"

  timeout "$OPENSSL_TIMEOUT" bash -c \
    "echo | openssl s_client -servername ${host} -connect ${host}:443 >/dev/null 2>&1" \
      && ok "TLS OK: ${host}:443" \
      || { err "TLS FAILED: ${host}:443"; return 1; }
}

https_check(){
  local host="$1"
  [[ "$host" == *"*"* ]] && host="${host#*.}"

  curl -sS -I --connect-timeout "$CURL_TIMEOUT" "https://${host}" >/dev/null 2>&1 \
    && ok "HTTPS OK: https://${host}" \
    || { err "HTTPS FAILED: https://${host}"; return 1; }
}

# ------------------------------------------------------------------------------
# Execution
# ------------------------------------------------------------------------------

h1 "Defender for Containers NODE Connectivity Check (Public Mode)"

[[ -n "${HTTPS_PROXY:-}" || -n "${HTTP_PROXY:-}" ]] \
  && echo -e "${COLOR_DIM}Proxy detected → HTTPS_PROXY=${HTTPS_PROXY:-<unset>}${COLOR_RESET}"

# DNS
h1 "1) DNS Checks"
for host in "${DEFENDER_ENDPOINTS[@]}"; do
  dns_check "$host" && PASSED+=("DNS:$host") || FAILED+=("DNS:$host")
done

# TLS
h1 "2) TLS Handshake Checks (443)"
for host in "${DEFENDER_ENDPOINTS[@]}"; do
  tls_check "$host" && PASSED+=("TLS:$host") || FAILED+=("TLS:$host")
done

# HTTPS Reachability
h1 "3) HTTPS Reachability Checks (443)"
for host in "${DEFENDER_ENDPOINTS[@]}"; do
  https_check "$host" && PASSED+=("HTTPS:$host") || FAILED+=("HTTPS:$host")
done

h1 "Summary"
echo -e "Passed: ${COLOR_OK}${#PASSED[@]}${COLOR_RESET}  |  Failed: ${COLOR_ERR}${#FAILED[@]}${COLOR_RESET}"

if (( ${#FAILED[@]} > 0 )); then
  echo -e "${COLOR_ERR}Failures:${COLOR_RESET}"
  for f in "${FAILED[@]}"; do echo " - $f"; done

  echo -e "\nTroubleshooting:"
  echo " - Ensure outbound HTTPS to *.securitycenter.azure.com and *.vulnerability.assessment.azure.com"
  echo " - Ensure mcr.microsoft.com and *.data.mcr.microsoft.com reachable for Defender images"
  echo " - Ensure *.blob.core.windows.net reachable for Defender artifacts"
  echo " - Disable TLS inspection for all Defender ingestion domains"
  exit 1
else
  echo -e "${COLOR_OK}All Defender for Containers connectivity checks passed.${COLOR_RESET}"
  exit 0
fi