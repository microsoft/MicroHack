#!/usr/bin/env bash
set -euo pipefail


# ------------------------------------------------------------------------------
# Synopsis: Azure Arc Connectivity Validation Script (In‑Cluster Execution)
#
# This script validates the network connectivity required for Azure Arc–
# enabled Kubernetes onboarding and steady‑state operation. It focuses
# exclusively on the endpoints required by the Arc agents (no Cluster Connect
# or Service Bus checks).
#
# Purpose:
# - Verify outbound connectivity from inside the Kubernetes cluster.
# - Ensure Arc agents can reach all mandatory Azure control‑plane and
#   data‑plane endpoints.
# - Validate DNS resolution, TLS handshake, and HTTPS accessibility.
# - Detect firewall, proxy, TLS inspection, or egress restrictions that may
#   break Arc onboarding, GitOps, extensions, policy, or identity flows.
#
# Validated Functional Areas:
# - Azure Resource Manager (management.azure.com)
# - KubernetesConfiguration data-plane (GitOps status/config delivery)
# - Azure Active Directory token retrieval for Arc agents
# - Managed Identity certificate retrieval (his.arc endpoints)
# - Microsoft Container Registry (MCR) image pullability for Arc agents
# - Optional: graph.microsoft.com if Azure RBAC for Kubernetes is enabled
#
# How to Run Inside the Cluster:
#
# 1. Start an Ubuntu diagnostic pod with resource limits on master node:
#    kubectl run arccheck --image=ubuntu:22.04 -it --restart=Never -- bash
#    
#    If you already have a suitable pod, you can exec into it instead:
#    kubectl exec -it <pod-name> -- bash
#    i.e. kubectl exec -it arccheck -- bash
#
# 2. Install required tools inside the pod (optimized for speed):
#    apt update --quiet && apt install -y --no-install-recommends \
#      curl dnsutils openssl ca-certificates
#
# 3. Download the script into the pod:
#    curl -sSL -o arc-node-onboarding-check.sh <RAW_GITHUB_URL>
#
# 4. Make it executable:
#    chmod +x arc-node-onboarding-check.sh
#
# 5. Run the script:
#    ./arc-node-onboarding-check.sh westeurope
#
# Output:
# - Per-endpoint DNS / TLS / HTTPS validation results.
# - Summary indicating PASS/FAIL.
# - Remediation hints for proxies, TLS inspection, or blocked egress.
#
# Exit Codes:
# - 0 = All critical checks successful.
# - 1 = One or more required endpoints unreachable.
#
# Intended Audience:
# - Kubernetes administrators validating Arc readiness.
# - Network/security teams reviewing outbound requirements.
# - Architects designing hybrid or on-prem Arc deployments.
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

RESOLVER_CMD=""
if command -v dig >/dev/null 2>&1; then RESOLVER_CMD="dig +short"
elif command -v nslookup >/dev/null 2>&1; then RESOLVER_CMD="nslookup"
elif command -v getent >/dev/null 2>&1; then RESOLVER_CMD="getent hosts"
else echo "Need dig/nslookup/getent"; exit 2; fi

# Node-required endpoints (continuous)
NODE_CORE=(
  "management.azure.com"                           # ARM heartbeat/registration
  "${REGION}.dp.kubernetesconfiguration.azure.com" # GitOps data-plane
  "login.microsoftonline.com"                      # AAD tokens
  "${REGION}.login.microsoft.com"                  # regional AAD
  "login.windows.net"                              # legacy AAD
  "mcr.microsoft.com"                              # agent/ext images
  "gbl.his.arc.azure.com"                          # MSI certs
  "graph.microsoft.com"                            # RBAC (optional but checked)
  "linuxgeneva-microsoft.azurecr.io"               # some extensions payloads
  "${REGION}.obo.arc.azure.com:8084"               # Arc agent communication
)

PASSED=(); FAILED=()

check_dns(){ local h="$1"
  # Strip port if present for DNS lookup
  local host_only="${h%:*}"
  if [[ "$RESOLVER_CMD" == "dig +short" ]]; then
    dig +short "$host_only" | grep -E '^[0-9a-fA-F:.]+$' >/dev/null && ok "DNS resolves: $host_only" || { err "DNS failed: $host_only"; return 1; }
  elif [[ "$RESOLVER_CMD" == "nslookup" ]]; then
    nslookup "$host_only" >/dev/null 2>&1 && ok "DNS resolves: $host_only" || { err "DNS failed: $host_only"; return 1; }
  else
    getent hosts "$host_only" >/dev/null 2>&1 && ok "DNS resolves: $host_only" || { err "DNS failed: $host_only"; return 1; }
  fi
}

check_tls(){ local h="$1"
  local host_only="${h%:*}"
  local port="${h##*:}"
  # If no port specified, default to 443
  [[ "$port" == "$host_only" ]] && port="443"
  timeout "${OPENSSL_TIMEOUT}" bash -c "echo | openssl s_client -servername ${host_only} -connect ${host_only}:${port} >/dev/null 2>&1" \
    && ok "TLS handshake OK: ${host_only}:${port}" || { err "TLS handshake failed: ${host_only}:${port}"; return 1; }
}

check_https(){ local h="$1"
  local host_only="${h%:*}"
  local port="${h##*:}"
  # If no port specified, default to 443
  [[ "$port" == "$host_only" ]] && port="443"
  # For non-443 ports, use HTTP instead of HTTPS and just test connectivity
  if [[ "$port" == "443" ]]; then
    curl -sS -I --connect-timeout "${CURL_TIMEOUT}" "https://${h}" >/dev/null 2>&1 \
      && ok "HTTPS reachable: https://${h}" || { err "HTTPS blocked/unreachable: https://${h}"; return 1; }
  else
    # For custom ports, test TCP connectivity instead of HTTPS
    timeout "${CURL_TIMEOUT}" bash -c "echo >/dev/tcp/${host_only}/${port}" 2>/dev/null \
      && ok "TCP reachable: ${host_only}:${port}" || { err "TCP blocked/unreachable: ${host_only}:${port}"; return 1; }
  fi
}

mcr_probe(){
  local okflag=1
  curl -sS -I --connect-timeout "${CURL_TIMEOUT}" "https://mcr.microsoft.com/v2/" >/dev/null 2>&1 \
    && ok "MCR registry reachable: mcr.microsoft.com" || { err "MCR blocked/unreachable: mcr.microsoft.com"; okflag=0; }
  curl -sS -I --connect-timeout "${CURL_TIMEOUT}" "https://mcr.microsoft.com/v2/azurearck8s/agent/tags/list" >/dev/null 2>&1 \
    && ok "MCR path probe OK: /v2/azurearck8s/agent" || warn "MCR path probe failed (CDN/edge filtering?)."
  return $([[ $okflag -eq 1 ]])
}

h1 "Azure Arc NODE onboarding/steady-state checks (region: ${REGION})"
[[ -n "${HTTPS_PROXY:-}" || -n "${HTTP_PROXY:-}" ]] && echo -e "${COLOR_DIM}Proxy: HTTPS_PROXY=${HTTPS_PROXY:-<unset>} HTTP_PROXY=${HTTP_PROXY:-<unset>}${COLOR_RESET}"

h1 "1) DNS"
for h in "${NODE_CORE[@]}"; do
  check_dns "$h" && PASSED+=("DNS:$h") || FAILED+=("DNS:$h")
done

h1 "2) TLS handshakes (443)"
for h in "${NODE_CORE[@]}"; do
  check_tls "$h" && PASSED+=("TLS:$h") || FAILED+=("TLS:$h")
done

h1 "3) HTTPS reachability (443)"
for h in "${NODE_CORE[@]}"; do
  check_https "$h" && PASSED+=("HTTPS:$h") || FAILED+=("HTTPS:$h")
done

h1 "4) MCR probes (agent/ext images)"
mcr_probe && PASSED+=("MCR:mcr.microsoft.com") || FAILED+=("MCR:mcr.microsoft.com")

h1 "Summary (NODE)"
echo -e "Passed: ${COLOR_OK}${#PASSED[@]}${COLOR_RESET} | Failed: ${COLOR_ERR}${#FAILED[@]}${COLOR_RESET}"
if (( ${#FAILED[@]} > 0 )); then
  echo -e "${COLOR_ERR}Failures:${COLOR_RESET}"; for f in "${FAILED[@]}"; do echo " - $f"; done
  echo -e "\nHints:\n - Disable TLS inspection for Arc endpoints and MCR/CDN.\n - If pods use a different egress (egress gateway), run this from inside a Pod for parity."
  exit 1
else
  echo -e "${COLOR_OK}All critical node onboarding/steady-state paths look good.${COLOR_RESET}"; exit 0
fi
