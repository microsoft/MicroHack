#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Synopsis: Azure Arc CLIENT Onboarding Connectivity Validation Script
#
# This script validates the network connectivity required on a *client machine*
# (e.g., admin workstation, jump host, DevOps runner) to perform Azure Arc–
# enabled Kubernetes **onboarding** and Arc management operations using:
#   - az login
#   - az connectedk8s connect
#   - GitOps (KubernetesConfiguration) authoring commands
#   - kubectl (local execution only; no Cluster Connect checks)
#
# The script verifies only the endpoints needed for:
#   ✔ Azure Resource Manager (ARM)
#   ✔ Azure Active Directory authentication flows
#   ✔ GitOps management-plane interactions from the CLI
#   ✔ Optional Azure RBAC (graph.microsoft.com)
#   ✔ kubectl binary download (dl.k8s.io)
#   ✔ Basic Microsoft Container Registry access (MCR)
#
# It intentionally excludes:
#   ✘ Cluster Connect
#   ✘ Service Bus WebSockets
#   ✘ Guest Notification Service regional endpoints
#   ✘ Any Arc Portal UI endpoints
#
# Purpose:
# - Ensure your client has correct outbound access to authenticate, onboard,
#   register, and manage Azure Arc–enabled Kubernetes resources.
# - Detect issues such as blocked outbound HTTPS, DNS failures, TLS inspection,
#   or restricted access to Microsoft endpoints required for Arc onboarding.
#
# Validated Functional Areas:
# - ARM API: management.azure.com
# - AAD authentication: login.microsoftonline.com, <region>.login.microsoft.com,
#   login.windows.net
# - GitOps management-plane: <region>.dp.kubernetesconfiguration.azure.com
# - Optional RBAC: graph.microsoft.com
# - kubectl download: dl.k8s.io
# - Optional: mcr.microsoft.com registry availability
#
# How to Run on Your Client:
#
# 1. Download the script:
#    curl -sSL -o arc-client-onboarding-check.sh <RAW_GITHUB_URL>
#
# 2. Make it executable:
#    chmod +x arc-client-onboarding-check.sh
#
# 3. Execute it with your Azure region:
#    ./arc-client-onboarding-check.sh westeurope
#
# Output:
# - DNS, TLS, and HTTPS validation results per endpoint
# - PASS/FAIL summary
# - Remediation hints for network/proxy/TLS inspection issues
#
# Exit Codes:
# - 0 = All critical connectivity checks passed
# - 1 = One or more required endpoints unreachable
#
# Intended Audience:
# - Operators onboarding Arc-enabled Kubernetes clusters
# - Network and security engineers validating client egress paths
# - Architects preparing hybrid network readiness for Arc deployments
#
# ------------------------------------------------------------------------------

REGION="${1:-westeurope}"
CURL_TIMEOUT=7
OPENSSL_TIMEOUT=7
COLOR_OK="\033[32m"; COLOR_ERR="\033[31m"; COLOR_WARN="\033[33m"; COLOR_DIM="\033[90m"; COLOR_RESET="\033[0m"

h1(){ echo -e "\n\033[1m$1\033[0m"; }
ok(){ echo -e "${COLOR_OK}✔${COLOR_RESET} $1"; }
err(){ echo -e "${COLOR_ERR}✖${COLOR_RESET} $1"; }
warn(){ echo -e "${COLOR_WARN}⚠${COLOR_RESET} $1"; }

# Resolver selection
RESOLVER_CMD=""
if command -v dig >/dev/null 2>&1; then RESOLVER_CMD="dig +short"
elif command -v nslookup >/dev/null 2>&1; then RESOLVER_CMD="nslookup"
elif command -v getent >/dev/null 2>&1; then RESOLVER_CMD="getent hosts"
else echo "Need dig/nslookup/getent"; exit 2; fi

# Client-relevant endpoints (minimal)
CLIENT_CORE=(
  "management.azure.com"                           # ARM
  "login.microsoftonline.com"                      # AAD
  "${REGION}.login.microsoft.com"                  # regional AAD
  "login.windows.net"                              # legacy AAD
  "${REGION}.dp.kubernetesconfiguration.azure.com" # GitOps mgmt-plane
  "graph.microsoft.com"                            # Azure RBAC (optional but checked)
  "dl.k8s.io"                                      # kubectl download
)

CLIENT_MCR=("mcr.microsoft.com")

PASSED=(); FAILED=()

check_dns(){ local h="$1"
  if [[ "$RESOLVER_CMD" == "dig +short" ]]; then
    dig +short "$h" | grep -E '^[0-9a-fA-F:.]+$' >/dev/null && ok "DNS resolves: $h" || { err "DNS failed: $h"; return 1; }
  elif [[ "$RESOLVER_CMD" == "nslookup" ]]; then
    nslookup "$h" >/dev/null 2>&1 && ok "DNS resolves: $h" || { err "DNS failed: $h"; return 1; }
  else
    getent hosts "$h" >/dev/null 2>&1 && ok "DNS resolves: $h" || { err "DNS failed: $h"; return 1; }
  fi
}

check_tls(){ local h="$1"
  timeout "${OPENSSL_TIMEOUT}" bash -c "echo | openssl s_client -servername ${h} -connect ${h}:443 >/dev/null 2>&1" \
    && ok "TLS handshake OK: ${h}:443" || { err "TLS handshake failed: ${h}:443"; return 1; }
}

check_https(){ local h="$1"
  curl -sS -I --connect-timeout "${CURL_TIMEOUT}" "https://${h}" >/dev/null 2>&1 \
    && ok "HTTPS reachable: https://${h}" || { err "HTTPS blocked/unreachable: https://${h}"; return 1; }
}

mcr_probe(){
  local okflag=1
  curl -sS -I --connect-timeout "${CURL_TIMEOUT}" "https://mcr.microsoft.com/v2/" >/dev/null 2>&1 \
    && ok "MCR registry reachable: mcr.microsoft.com" || { err "MCR blocked/unreachable: mcr.microsoft.com"; okflag=0; }
  curl -sS -I --connect-timeout "${CURL_TIMEOUT}" "https://mcr.microsoft.com/v2/azurearck8s/agent/tags/list" >/dev/null 2>&1 \
    && ok "MCR path probe OK: /v2/azurearck8s/agent" || warn "MCR path probe failed (CDN filtering possible)."
  return $([[ $okflag -eq 1 ]])
}

h1 "Azure Arc CLIENT onboarding checks (region: ${REGION})"
[[ -n "${HTTPS_PROXY:-}" || -n "${HTTP_PROXY:-}" ]] && echo -e "${COLOR_DIM}Proxy: HTTPS_PROXY=${HTTPS_PROXY:-<unset>} HTTP_PROXY=${HTTP_PROXY:-<unset>}${COLOR_RESET}"

h1 "1) DNS"
for h in "${CLIENT_CORE[@]}" "${CLIENT_MCR[@]}"; do
  check_dns "$h" && PASSED+=("DNS:$h") || FAILED+=("DNS:$h")
done

h1 "2) TLS handshakes (443)"
for h in "${CLIENT_CORE[@]}" "${CLIENT_MCR[@]}"; do
  check_tls "$h" && PASSED+=("TLS:$h") || FAILED+=("TLS:$h")
done

h1 "3) HTTPS reachability (443)"
for h in "${CLIENT_CORE[@]}" "${CLIENT_MCR[@]}"; do
  check_https "$h" && PASSED+=("HTTPS:$h") || FAILED+=("HTTPS:$h")
done

h1 "4) Optional MCR probes"
mcr_probe && PASSED+=("MCR:mcr.microsoft.com") || FAILED+=("MCR:mcr.microsoft.com")

h1 "Summary (CLIENT)"
echo -e "Passed: ${COLOR_OK}${#PASSED[@]}${COLOR_RESET} | Failed: ${COLOR_ERR}${#FAILED[@]}${COLOR_RESET}"
if (( ${#FAILED[@]} > 0 )); then
  echo -e "${COLOR_ERR}Failures:${COLOR_RESET}"; for f in "${FAILED[@]}"; do echo " - $f"; done
  echo -e "\nHints:\n - Disable TLS inspection for these FQDNs.\n - If a proxy is in use, verify NO_PROXY excludes cluster private ranges."
  exit 1
else
  echo -e "${COLOR_OK}All critical client onboarding paths look good.${COLOR_RESET}"; exit 0
fi
