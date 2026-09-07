#!/usr/bin/env bash
# Invoke with Bash from the Adaptive Apps MicroHack root; executable bits are not required.
set -euo pipefail
trap 'echo "ERROR: K3s preparation failed at line ${LINENO}. Review Azure Policy and role-assignment errors above." >&2' ERR

TEMP_FILES=()
cleanup_temp_files() {
  local file
  for file in "${TEMP_FILES[@]}"; do
    [[ -n "$file" ]] && rm -f "$file"
  done
}
trap cleanup_temp_files EXIT

readonly MODE="${1:-provision}"
readonly K3S_API_PORT="6443"
readonly KUBECONFIG_CHUNK_SIZE="1800"

AZURE_LOCATION="${AZURE_LOCATION:-westeurope}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-adaptive-apps}"
VNET_NAME="${VNET_NAME:-vnet-adaptive-apps}"
VNET_PREFIX="${VNET_PREFIX:-10.42.0.0/16}"
K3S_SUBNET_NAME="${K3S_SUBNET_NAME:-snet-k3s}"
K3S_SUBNET_PREFIX="${K3S_SUBNET_PREFIX:-10.42.0.0/24}"
BASTION_SUBNET_PREFIX="${BASTION_SUBNET_PREFIX:-10.42.1.0/26}"
K3S_NSG_NAME="${K3S_NSG_NAME:-nsg-adaptive-apps-k3s}"
K3S_NIC_NAME="${K3S_NIC_NAME:-nic-adaptive-apps-k3s}"
K3S_VM_NAME="${K3S_VM_NAME:-vm-adaptive-apps-k3s}"
K3S_VM_SIZE="${K3S_VM_SIZE:-Standard_D4s_v5}"
# Four-vCPU, 16 GiB x64 sizes in decreasing order of preference. Regions and
# subscriptions differ in what they offer, so the script falls back automatically.
# These are Azure VM sizes: an arm64 workstation still provisions an x64 Azure VM,
# and the Ubuntu2204 image alias used below resolves to an x64 image.
read -r -a K3S_VM_SIZE_CANDIDATES <<<"${K3S_VM_SIZE_CANDIDATES:-${K3S_VM_SIZE} Standard_D4as_v5 Standard_D4s_v4 Standard_D4as_v4 Standard_D4s_v3 Standard_D4a_v4}"
K3S_ADMIN_USERNAME="${K3S_ADMIN_USERNAME:-azureuser}"
BASTION_PUBLIC_IP_NAME="${BASTION_PUBLIC_IP_NAME:-pip-adaptive-apps-bastion}"
BASTION_NAME="${BASTION_NAME:-bas-adaptive-apps}"
K3S_LOCAL_PORT="${K3S_LOCAL_PORT:-16443}"
# Outbound internet is required to install K3s and pull container images. Azure is
# retiring implicit default outbound access: for API versions released after
# 2026-03-31, new virtual networks default to private subnets with no outbound path.
# The default here is an explicit NAT gateway, which keeps the subnet private, gives a
# deterministic egress IP, and is the durable option. It adds an hourly charge plus
# per-GB data processing. Set K3S_ENABLE_NAT_GATEWAY=false to fall back to explicitly
# enabled default outbound access, which is free but is itself being retired.
K3S_ENABLE_NAT_GATEWAY="${K3S_ENABLE_NAT_GATEWAY:-true}"
NAT_GATEWAY_NAME="${NAT_GATEWAY_NAME:-natgw-adaptive-apps}"
NAT_PUBLIC_IP_NAME="${NAT_PUBLIC_IP_NAME:-pip-adaptive-apps-nat}"
K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"
K3S_TUNNEL_STATE_DIR="${K3S_TUNNEL_STATE_DIR:-$HOME/.kube/adaptive-apps-bastion}"
readonly TUNNEL_PID_FILE="${K3S_TUNNEL_STATE_DIR}/tunnel.pid"
readonly TUNNEL_LOG_FILE="${K3S_TUNNEL_STATE_DIR}/tunnel.log"

if (($# > 1)); then
  echo "Only one mode argument is supported." >&2
  exit 2
fi

usage() {
  cat <<'EOF'
Usage: bash resources/prepare-k3s-azure-vm.sh [provision|connect|status|disconnect]

  provision   Create or reuse the private K3s platform, retrieve kubeconfig, and connect.
              This is the default mode.
  connect     Re-establish the localhost Azure Bastion tunnel and validate K3s.
  status      Report local tunnel state without making Azure calls.
  disconnect  Stop only the recorded, identity-verified tunnel process.

Required for provision/connect:
  AZURE_SUBSCRIPTION   Target Azure subscription ID.

The kubeconfig endpoint defaults to https://127.0.0.1:16443. Override the local port
with K3S_LOCAL_PORT before provisioning and on every later connect command.
EOF
}

case "$MODE" in
  provision | connect | status | disconnect) ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_pid_running() {
  local process_stat

  is_integer "$1" && kill -0 "$1" 2>/dev/null || return 1
  [[ -r "/proc/${1}/stat" ]] || return 1
  process_stat="$(<"/proc/${1}/stat")"
  [[ "$process_stat" != *") Z "* ]]
}

tunnel_pid_matches() {
  local pid="$1"
  local command_line

  is_pid_running "$pid" || return 1
  [[ -r "/proc/${pid}/cmdline" ]] || return 1
  command_line="$(tr '\0' ' ' <"/proc/${pid}/cmdline")"
  # The Azure CLI launcher is a Bash wrapper that runs its Python entry point as a child
  # process rather than replacing itself, so both processes carry the same argument
  # signature. Match either one; the Bastion name, resource group, and both ports keep
  # the signature specific to this tunnel.
  [[ "$command_line" == *"network bastion tunnel"* ]] &&
    [[ "$command_line" == *"--name ${BASTION_NAME}"* ]] &&
    [[ "$command_line" == *"--resource-group ${RESOURCE_GROUP}"* ]] &&
    [[ "$command_line" == *"--resource-port ${K3S_API_PORT}"* ]] &&
    [[ "$command_line" == *"--port ${K3S_LOCAL_PORT}"* ]]
}

# Every live process carrying this tunnel's exact signature, including the Azure CLI
# Python child that actually owns the local listening socket.
list_tunnel_pids() {
  local pid_directory
  local pid

  for pid_directory in /proc/[0-9]*; do
    pid="${pid_directory#/proc/}"
    if tunnel_pid_matches "$pid"; then
      printf '%s\n' "$pid"
    fi
  done
}

stop_tunnel_pids() {
  local pid
  local remaining

  (($# > 0)) || return 0
  for pid in "$@"; do
    kill "$pid" 2>/dev/null || true
  done
  for _ in {1..20}; do
    remaining=0
    for pid in "$@"; do
      if is_pid_running "$pid"; then
        remaining=1
      fi
    done
    if ((remaining == 0)); then
      return 0
    fi
    sleep 1
  done
  return 1
}
local_port_ready() {
  timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/${K3S_LOCAL_PORT}" 2>/dev/null
}

read_recorded_pid() {
  [[ -f "$TUNNEL_PID_FILE" ]] || return 1
  tr -d '[:space:]' <"$TUNNEL_PID_FILE"
}

tunnel_status() {
  local pid

  if ! pid="$(read_recorded_pid)" || ! is_integer "$pid"; then
    echo "K3s Bastion tunnel is not recorded."
    return 1
  fi

  if ! tunnel_pid_matches "$pid"; then
    echo "K3s Bastion tunnel is not running; PID file is stale or belongs to another process."
    return 1
  fi

  if ! local_port_ready; then
    echo "K3s Bastion tunnel process ${pid} is running, but localhost:${K3S_LOCAL_PORT} is not ready."
    return 1
  fi

  echo "K3s Bastion tunnel is ready on https://127.0.0.1:${K3S_LOCAL_PORT} (PID ${pid})."
}

disconnect_tunnel() {
  local recorded
  local -a pids=()

  if recorded="$(read_recorded_pid 2>/dev/null)" && is_integer "$recorded"; then
    if is_pid_running "$recorded" && ! tunnel_pid_matches "$recorded"; then
      echo "Refusing to stop PID ${recorded}: it is not the recorded Adaptive Apps Bastion tunnel." >&2
      echo "Remove ${TUNNEL_PID_FILE} manually only after investigating that process." >&2
      return 1
    fi
  fi

  mapfile -t pids < <(list_tunnel_pids)

  if ((${#pids[@]} == 0)); then
    rm -f "$TUNNEL_PID_FILE"
    echo "No K3s Bastion tunnel is running."
    return 0
  fi

  if ! stop_tunnel_pids "${pids[@]}"; then
    echo "Tunnel PIDs ${pids[*]} did not stop after SIGTERM; they were not force-killed." >&2
    return 1
  fi

  rm -f "$TUNNEL_PID_FILE"
  echo "Stopped K3s Bastion tunnel PIDs ${pids[*]}."
}

if [[ "$MODE" == "status" ]]; then
  if tunnel_status; then
    exit 0
  fi
  exit 1
fi

if [[ "$MODE" == "disconnect" ]]; then
  if disconnect_tunnel; then
    exit 0
  fi
  exit 1
fi

for command_name in az base64 cut grep install jq kubectl nohup sed tail timeout tr wc; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

: "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION to the target subscription ID.}"
if ! is_integer "$K3S_LOCAL_PORT"; then
  echo "K3S_LOCAL_PORT must be an unprivileged TCP port from 1024 through 65535." >&2
  exit 1
fi
LOCAL_PORT_DECIMAL=$((10#$K3S_LOCAL_PORT))
readonly LOCAL_PORT_DECIMAL
((LOCAL_PORT_DECIMAL >= 1024 && LOCAL_PORT_DECIMAL <= 65535)) || {
  echo "K3S_LOCAL_PORT must be an unprivileged TCP port from 1024 through 65535." >&2
  exit 1
}
BASTION_PREFIX_LENGTH="${BASTION_SUBNET_PREFIX##*/}"
[[ "$BASTION_SUBNET_PREFIX" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] &&
  is_integer "$BASTION_PREFIX_LENGTH" &&
  ((10#$BASTION_PREFIX_LENGTH <= 26)) || {
  echo "BASTION_SUBNET_PREFIX must be an IPv4 CIDR with a /26 or larger address range." >&2
  exit 1
}

if ! az extension show --name bastion >/dev/null 2>&1; then
  echo "Azure CLI extension 'bastion' is required." >&2
  echo "Rebuild the devcontainer or run: az extension add --name bastion --upgrade --yes" >&2
  exit 1
fi

az account show >/dev/null 2>&1 || az login
az account set --subscription "$AZURE_SUBSCRIPTION"
SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
readonly SUBSCRIPTION_ID
readonly VM_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${K3S_VM_NAME}"

ensure_tunnel() {
  local existing_pid
  local new_pid

  install -d -m 0700 "$K3S_TUNNEL_STATE_DIR"

  if existing_pid="$(read_recorded_pid 2>/dev/null)" && is_integer "$existing_pid"; then
    if tunnel_pid_matches "$existing_pid" && local_port_ready; then
      echo "Reusing K3s Bastion tunnel PID ${existing_pid}."
      return
    fi
    if is_pid_running "$existing_pid" && tunnel_pid_matches "$existing_pid"; then
      echo "Replacing unready K3s Bastion tunnel PID ${existing_pid}."
      disconnect_tunnel
    elif is_pid_running "$existing_pid"; then
      echo "Refusing to replace unrelated PID ${existing_pid} from ${TUNNEL_PID_FILE}." >&2
      return 1
    else
      rm -f "$TUNNEL_PID_FILE"
    fi
  fi

  if local_port_ready; then
    local -a orphan_pids=()
    mapfile -t orphan_pids < <(list_tunnel_pids)
    if ((${#orphan_pids[@]} > 0)); then
      echo "Reclaiming orphaned Adaptive Apps Bastion tunnel PIDs ${orphan_pids[*]}."
      if ! stop_tunnel_pids "${orphan_pids[@]}"; then
        echo "Orphaned Bastion tunnel PIDs ${orphan_pids[*]} did not stop after SIGTERM." >&2
        return 1
      fi
      rm -f "$TUNNEL_PID_FILE"
    fi
  fi

  if local_port_ready; then
    echo "Local port ${K3S_LOCAL_PORT} is in use by a process that is not an Adaptive Apps tunnel." >&2
    echo "Choose another K3S_LOCAL_PORT or stop that process explicitly." >&2
    return 1
  fi

  : >"$TUNNEL_LOG_FILE"
  chmod 0600 "$TUNNEL_LOG_FILE"
  nohup az network bastion tunnel \
    --name "$BASTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --target-resource-id "$VM_RESOURCE_ID" \
    --resource-port "$K3S_API_PORT" \
    --port "$K3S_LOCAL_PORT" \
    --only-show-errors \
    >"$TUNNEL_LOG_FILE" 2>&1 </dev/null &
  new_pid="$!"
  printf '%s\n' "$new_pid" >"$TUNNEL_PID_FILE"
  chmod 0600 "$TUNNEL_PID_FILE"

  for _ in {1..60}; do
    if local_port_ready; then
      tunnel_pid_matches "$new_pid" || {
        echo "Local port opened, but the recorded tunnel process identity changed." >&2
        return 1
      }
      echo "K3s Bastion tunnel is ready on localhost:${K3S_LOCAL_PORT} (PID ${new_pid})."
      return
    fi
    if ! is_pid_running "$new_pid"; then
      echo "Azure Bastion tunnel exited before localhost:${K3S_LOCAL_PORT} became ready." >&2
      tail -n 20 "$TUNNEL_LOG_FILE" >&2
      rm -f "$TUNNEL_PID_FILE"
      return 1
    fi
    sleep 2
  done

  echo "Timed out waiting for Azure Bastion tunnel on localhost:${K3S_LOCAL_PORT}." >&2
  tail -n 20 "$TUNNEL_LOG_FILE" >&2
  return 1
}

validate_k3s() {
  local configured_server
  local expected_server="https://127.0.0.1:${K3S_LOCAL_PORT}"

  [[ -s "$K3S_KUBECONFIG" ]] || {
    echo "Kubeconfig not found at ${K3S_KUBECONFIG}; run provision mode first." >&2
    return 1
  }
  export KUBECONFIG="$K3S_KUBECONFIG"
  configured_server="$(kubectl config view \
    --kubeconfig "$K3S_KUBECONFIG" \
    --minify \
    --output jsonpath='{.clusters[0].cluster.server}')"
  [[ "$configured_server" == "$expected_server" ]] || {
    echo "Kubeconfig endpoint ${configured_server} does not match ${expected_server}." >&2
    echo "Use the same K3S_LOCAL_PORT as provisioning, or rerun provision mode." >&2
    return 1
  }
  kubectl config use-context "$K3S_CONTEXT" >/dev/null
  kubectl --request-timeout=15s get --raw="/readyz" | grep -qx "ok"
  kubectl wait --for=condition=Ready nodes --all --timeout=5m
  kubectl get nodes -o wide
}

# The Radius CLI resolves part of its installation through the default kubeconfig rather
# than through KUBECONFIG, so the K3s context must also be registered there. The
# dedicated K3s file remains the documented way to target K3s explicitly.
register_k3s_context_in_default_kubeconfig() {
  local default_kubeconfig="$HOME/.kube/config"
  local merged_file

  merged_file="$(mktemp)"
  chmod 0600 "$merged_file"
  TEMP_FILES+=("$merged_file")

  KUBECONFIG="${default_kubeconfig}:${K3S_KUBECONFIG}" \
    kubectl config view --flatten >"$merged_file"
  KUBECONFIG="$merged_file" kubectl config get-contexts --output name |
    grep -qx "$K3S_CONTEXT" || {
    echo "Could not register the ${K3S_CONTEXT} context in ${default_kubeconfig}." >&2
    return 1
  }
  install -m 0600 "$merged_file" "$default_kubeconfig"
  rm -f "$merged_file"
}

if [[ "$MODE" == "connect" ]]; then
  az vm show --resource-group "$RESOURCE_GROUP" --name "$K3S_VM_NAME" >/dev/null || {
    echo "K3s VM ${K3S_VM_NAME} was not found; run provision mode first." >&2
    exit 1
  }
  CONNECT_NIC_ID="$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$K3S_VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" \
    --output tsv)"
  CONNECT_PUBLIC_IP_ID="$(az network nic show \
    --ids "$CONNECT_NIC_ID" \
    --query "ipConfigurations[?publicIPAddress!=null].publicIPAddress.id | [0]" \
    --output tsv)"
  [[ -z "$CONNECT_PUBLIC_IP_ID" ]] || {
    echo "Refusing to connect: legacy VM ${K3S_VM_NAME} still has a public IP." >&2
    echo "Run provision mode for explicit migration guidance." >&2
    exit 1
  }
  az vm start --resource-group "$RESOURCE_GROUP" --name "$K3S_VM_NAME" --output none
  CONNECT_BASTION_STATE="$(az network bastion show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --query "{state:provisioningState,sku:sku.name,tunneling:enableTunneling}" \
    --output json)"
  jq -e \
    '(.state == "Succeeded") and ((.sku == "Standard") or (.sku == "Premium")) and (.tunneling == true)' \
    <<<"$CONNECT_BASTION_STATE" >/dev/null || {
    echo "Bastion must be Succeeded, Standard or Premium, and have native tunneling enabled." >&2
    exit 1
  }
  ensure_tunnel
  validate_k3s
  register_k3s_context_in_default_kubeconfig
  exit
fi

AVAILABLE_VM_SIZES=""

# az vm list-skus already omits sizes the subscription cannot use. A Location
# restriction blocks the whole region; a Zone restriction only removes individual
# availability zones and does not block the regional, non-zonal deployment used here.
load_available_vm_sizes() {
  [[ -z "$AVAILABLE_VM_SIZES" ]] || return 0
  AVAILABLE_VM_SIZES="$(az vm list-skus \
    --location "$AZURE_LOCATION" \
    --resource-type virtualMachines \
    --query "[?length(restrictions[?type=='Location']) == \`0\`].name" \
    --output tsv)"
}

vm_size_is_available() {
  load_available_vm_sizes
  grep -qx -- "$1" <<<"$AVAILABLE_VM_SIZES"
}

# Capacity and quota problems only surface when the control plane tries to allocate.
is_capacity_error() {
  grep -Eqi 'AllocationFailed|SkuNotAvailable|ZonalAllocationFailed|OverconstrainedAllocationRequest|QuotaExceeded|exceeding approved .* quota|InsufficientCapacity' "$1"
}

create_k3s_vm() {
  local size
  local create_log
  local attempted=0

  create_log="$(mktemp)"
  TEMP_FILES+=("$create_log")

  for size in "${K3S_VM_SIZE_CANDIDATES[@]}"; do
    if ! vm_size_is_available "$size"; then
      echo "VM size ${size} is not offered in ${AZURE_LOCATION} for this subscription; trying the next candidate." >&2
      continue
    fi
    attempted=1
    echo "Creating K3s VM ${K3S_VM_NAME} with size ${size}."
    if az vm create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_VM_NAME" \
      --location "$AZURE_LOCATION" \
      --image Ubuntu2204 \
      --size "$size" \
      --admin-username "$K3S_ADMIN_USERNAME" \
      --authentication-type ssh \
      --generate-ssh-keys \
      --nics "$K3S_NIC_NAME" \
      --os-disk-size-gb 64 \
      --storage-sku StandardSSD_LRS \
      --output none 2>"$create_log"; then
      return 0
    fi

    cat "$create_log" >&2
    if ! is_capacity_error "$create_log"; then
      return 1
    fi

    echo "VM size ${size} has no capacity or quota in ${AZURE_LOCATION}; removing the failed VM and trying the next size." >&2
    az vm delete \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_VM_NAME" \
      --yes \
      --output none 2>/dev/null || true
  done

  if ((attempted == 0)); then
    echo "None of the candidate VM sizes is offered in ${AZURE_LOCATION}: ${K3S_VM_SIZE_CANDIDATES[*]}" >&2
  else
    echo "Every candidate VM size failed to allocate in ${AZURE_LOCATION}: ${K3S_VM_SIZE_CANDIDATES[*]}" >&2
  fi
  echo "Set K3S_VM_SIZE_CANDIDATES to sizes offered in your region, or choose another AZURE_LOCATION." >&2
  return 1
}

create_or_validate_subnet() {
  local subnet_name="$1"
  local subnet_prefix="$2"
  local default_outbound="${3:-}"
  local existing_prefix
  local -a create_args=()

  existing_prefix="$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$subnet_name" \
    --query addressPrefix \
    --output tsv 2>/dev/null || true)"
  if [[ -z "$existing_prefix" ]]; then
    if [[ -n "$default_outbound" ]]; then
      create_args+=(--default-outbound "$default_outbound")
    fi
    az network vnet subnet create \
      --resource-group "$RESOURCE_GROUP" \
      --vnet-name "$VNET_NAME" \
      --name "$subnet_name" \
      --address-prefixes "$subnet_prefix" \
      "${create_args[@]}" \
      --output none
  elif [[ "$existing_prefix" != "$subnet_prefix" ]]; then
    echo "Subnet ${subnet_name} uses ${existing_prefix}, expected ${subnet_prefix}." >&2
    echo "Choose matching variables or use a new VNET_NAME; the script will not reshape an existing subnet." >&2
    return 1
  fi
}

# Guarantee the K3s subnet has a working outbound path, whichever posture is selected.
ensure_k3s_outbound() {
  local current_nat
  local current_default_outbound

  current_nat="$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$K3S_SUBNET_NAME" \
    --query "natGateway.id" \
    --output tsv 2>/dev/null || true)"
  current_default_outbound="$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$K3S_SUBNET_NAME" \
    --query "defaultOutboundAccess" \
    --output tsv 2>/dev/null || true)"

  if [[ "${K3S_ENABLE_NAT_GATEWAY,,}" == "true" ]]; then
    if [[ -z "$current_nat" ]]; then
      echo "Configuring an explicit NAT gateway for outbound access."
      az network public-ip show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NAT_PUBLIC_IP_NAME" >/dev/null 2>&1 ||
        az network public-ip create \
          --resource-group "$RESOURCE_GROUP" \
          --name "$NAT_PUBLIC_IP_NAME" \
          --location "$AZURE_LOCATION" \
          --sku Standard \
          --allocation-method Static \
          --version IPv4 \
          --output none
      az network nat gateway show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NAT_GATEWAY_NAME" >/dev/null 2>&1 ||
        az network nat gateway create \
          --resource-group "$RESOURCE_GROUP" \
          --name "$NAT_GATEWAY_NAME" \
          --location "$AZURE_LOCATION" \
          --public-ip-addresses "$NAT_PUBLIC_IP_NAME" \
          --idle-timeout 10 \
          --output none
      az network vnet subnet update \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$K3S_SUBNET_NAME" \
        --nat-gateway "$NAT_GATEWAY_NAME" \
        --output none
    fi

    # A nonprivate subnet can still receive a platform-assigned fallback outbound IP
    # alongside the NAT gateway. Keeping it private makes the NAT public IP the only
    # egress address. Removing an already-assigned fallback IP needs a VM restart.
    if [[ "${current_default_outbound,,}" != "false" ]]; then
      az network vnet subnet update \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$K3S_SUBNET_NAME" \
        --default-outbound false \
        --output none
      [[ -z "$current_default_outbound" ]] || K3S_OUTBOUND_REOPENED=1
    fi
    return 0
  fi

  if [[ -n "$current_nat" ]]; then
    return 0
  fi

  # An explicit false blocks the K3s installer. Reopening the subnet only takes effect
  # after the VM is deallocated and started again, which the caller handles.
  if [[ "${current_default_outbound,,}" == "false" ]]; then
    echo "Subnet ${K3S_SUBNET_NAME} is private and has no NAT gateway; enabling default outbound access." >&2
    az network vnet subnet update \
      --resource-group "$RESOURCE_GROUP" \
      --vnet-name "$VNET_NAME" \
      --name "$K3S_SUBNET_NAME" \
      --default-outbound true \
      --output none
    K3S_OUTBOUND_REOPENED=1
  fi
}

echo "Provisioning private K3s network and Azure Bastion."
echo "FDPO policy denials require a compliant region/SKU or an administrator-approved exemption."
echo "Creating network resources requires Contributor or Network Contributor permissions."

az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION" --output none

if ! az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" >/dev/null 2>&1; then
  az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --location "$AZURE_LOCATION" \
    --address-prefixes "$VNET_PREFIX" \
    --output none
elif ! az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --query "addressSpace.addressPrefixes" \
  --output json | jq -e --arg prefix "$VNET_PREFIX" 'index($prefix) != null' >/dev/null; then
  echo "VNet ${VNET_NAME} does not contain expected address prefix ${VNET_PREFIX}." >&2
  exit 1
fi

K3S_OUTBOUND_REOPENED=0

if [[ "${K3S_ENABLE_NAT_GATEWAY,,}" == "true" ]]; then
  create_or_validate_subnet "$K3S_SUBNET_NAME" "$K3S_SUBNET_PREFIX" false
else
  create_or_validate_subnet "$K3S_SUBNET_NAME" "$K3S_SUBNET_PREFIX" true
fi
create_or_validate_subnet "AzureBastionSubnet" "$BASTION_SUBNET_PREFIX"
ensure_k3s_outbound

az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_NSG_NAME" \
  --location "$AZURE_LOCATION" \
  --output none

for rule in \
  "AllowBastionSsh:100:Allow:22:${BASTION_SUBNET_PREFIX}:Tcp" \
  "AllowBastionK3sApi:110:Allow:${K3S_API_PORT}:${BASTION_SUBNET_PREFIX}:Tcp" \
  "DenyOtherInbound:4096:Deny:*:*:*"; do
  IFS=: read -r rule_name priority access destination_port source_prefix protocol <<<"$rule"
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$K3S_NSG_NAME" \
    --name "$rule_name" \
    --priority "$priority" \
    --access "$access" \
    --protocol "$protocol" \
    --direction Inbound \
    --source-address-prefixes "$source_prefix" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges "$destination_port" \
    --output none
done

EXTRA_INBOUND_ALLOWS="$(az network nsg rule list \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$K3S_NSG_NAME" \
  --query "[?direction=='Inbound' && access=='Allow' && name!='AllowBastionSsh' && name!='AllowBastionK3sApi'].name" \
  --output tsv)"
readonly EXTRA_INBOUND_ALLOWS
[[ -z "$EXTRA_INBOUND_ALLOWS" ]] || {
  echo "NSG ${K3S_NSG_NAME} has unexpected inbound allow rules:" >&2
  echo "$EXTRA_INBOUND_ALLOWS" >&2
  echo "Remove those rules or select a new K3S_NSG_NAME; the script will not weaken isolation." >&2
  exit 1
}

if az vm show --resource-group "$RESOURCE_GROUP" --name "$K3S_VM_NAME" >/dev/null 2>&1; then
  EXISTING_NIC_ID="$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$K3S_VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" \
    --output tsv)"
  readonly EXISTING_NIC_ID
  EXISTING_PUBLIC_IP_ID="$(az network nic show \
    --ids "$EXISTING_NIC_ID" \
    --query "ipConfigurations[?publicIPAddress!=null].publicIPAddress.id | [0]" \
    --output tsv)"
  readonly EXISTING_PUBLIC_IP_ID
  if [[ -n "$EXISTING_PUBLIC_IP_ID" ]]; then
    echo "Legacy VM ${K3S_VM_NAME} still has a public IP. It will not be modified in place." >&2
    echo "Delete the old VM/NIC/public IP or use a new K3S_VM_NAME and K3S_NIC_NAME, then rerun." >&2
    exit 1
  fi
  EXISTING_SUBNET_ID="$(az network nic show \
    --ids "$EXISTING_NIC_ID" \
    --query "ipConfigurations[0].subnet.id" \
    --output tsv)"
  readonly EXISTING_SUBNET_ID
  if [[ "${EXISTING_SUBNET_ID##*/}" != "$K3S_SUBNET_NAME" ]]; then
    echo "Existing VM ${K3S_VM_NAME} is not attached to ${K3S_SUBNET_NAME}; refusing unsafe migration." >&2
    exit 1
  fi
  az network nic update \
    --ids "$EXISTING_NIC_ID" \
    --network-security-group "$K3S_NSG_NAME" \
    --output none
  # A subnet reopened for outbound only applies to a VM after a deallocate/start cycle.
  if ((K3S_OUTBOUND_REOPENED == 1)); then
    echo "Restarting ${K3S_VM_NAME} so it picks up the restored outbound path."
    az vm deallocate --resource-group "$RESOURCE_GROUP" --name "$K3S_VM_NAME" --output none
  fi
  az vm start --resource-group "$RESOURCE_GROUP" --name "$K3S_VM_NAME" --output none
else
  if ! az network nic show --resource-group "$RESOURCE_GROUP" --name "$K3S_NIC_NAME" >/dev/null 2>&1; then
    az network nic create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_NIC_NAME" \
      --location "$AZURE_LOCATION" \
      --vnet-name "$VNET_NAME" \
      --subnet "$K3S_SUBNET_NAME" \
      --network-security-group "$K3S_NSG_NAME" \
      --output none
  else
    ORPHAN_PUBLIC_IP_ID="$(az network nic show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_NIC_NAME" \
      --query "ipConfigurations[?publicIPAddress!=null].publicIPAddress.id | [0]" \
      --output tsv)"
    ORPHAN_SUBNET_ID="$(az network nic show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_NIC_NAME" \
      --query "ipConfigurations[0].subnet.id" \
      --output tsv)"
    [[ -z "$ORPHAN_PUBLIC_IP_ID" && "${ORPHAN_SUBNET_ID##*/}" == "$K3S_SUBNET_NAME" ]] || {
      echo "Existing NIC ${K3S_NIC_NAME} is not a private NIC in ${K3S_SUBNET_NAME}." >&2
      echo "Remove it or select a new K3S_NIC_NAME." >&2
      exit 1
    }
    az network nic update \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_NIC_NAME" \
      --network-security-group "$K3S_NSG_NAME" \
      --output none
  fi
  create_k3s_vm
fi

NIC_ID="$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_VM_NAME" \
  --query "networkProfile.networkInterfaces[0].id" \
  --output tsv)"
readonly NIC_ID
VM_PUBLIC_IP_ID="$(az network nic show \
  --ids "$NIC_ID" \
  --query "ipConfigurations[?publicIPAddress!=null].publicIPAddress.id | [0]" \
  --output tsv)"
readonly VM_PUBLIC_IP_ID
[[ -z "$VM_PUBLIC_IP_ID" ]] || {
  echo "Security validation failed: K3s VM has a public IP association." >&2
  exit 1
}
VM_PRIVATE_IP="$(az network nic show \
  --ids "$NIC_ID" \
  --query "ipConfigurations[0].privateIPAddress" \
  --output tsv)"
readonly VM_PRIVATE_IP

if ! az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BASTION_PUBLIC_IP_NAME" >/dev/null 2>&1; then
  az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_PUBLIC_IP_NAME" \
    --location "$AZURE_LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --version IPv4 \
    --output none
else
  BASTION_IP_PROPERTIES="$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_PUBLIC_IP_NAME" \
    --query "{sku:sku.name,allocation:publicIPAllocationMethod}" \
    --output json)"
  readonly BASTION_IP_PROPERTIES
  jq -e '.sku == "Standard" and .allocation == "Static"' \
    <<<"$BASTION_IP_PROPERTIES" >/dev/null || {
    echo "Existing Bastion public IP must use Standard SKU with static allocation." >&2
    exit 1
  }
fi

if az network bastion show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BASTION_NAME" >/dev/null 2>&1; then
  BASTION_SKU="$(az network bastion show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --query "sku.name" \
    --output tsv)"
  readonly BASTION_SKU
  BASTION_LOCATION="$(az network bastion show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --query location \
    --output tsv)"
  readonly BASTION_LOCATION
  case "$BASTION_SKU" in
    Standard | Premium) ;;
    *)
      az network bastion update \
        --resource-group "$RESOURCE_GROUP" \
        --name "$BASTION_NAME" \
        --location "$BASTION_LOCATION" \
        --sku name=Standard \
        --enable-tunneling true \
        --output none
      ;;
  esac
  az network bastion update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --location "$BASTION_LOCATION" \
    --enable-tunneling true \
    --output none
else
  az network bastion create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BASTION_NAME" \
    --location "$AZURE_LOCATION" \
    --vnet-name "$VNET_NAME" \
    --public-ip-address "$BASTION_PUBLIC_IP_NAME" \
    --sku Standard \
    --enable-tunneling true \
    --output none
fi
az network bastion wait \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BASTION_NAME" \
  --created \
  --timeout 1800

BASTION_STATE="$(az network bastion show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BASTION_NAME" \
  --query "{state:provisioningState,sku:sku.name,tunneling:enableTunneling}" \
  --output json)"
readonly BASTION_STATE
jq -e \
  '(.state == "Succeeded") and ((.sku == "Standard") or (.sku == "Premium")) and (.tunneling == true)' \
  <<<"$BASTION_STATE" >/dev/null || {
  echo "Bastion must be Succeeded, Standard or Premium, and have native tunneling enabled." >&2
  exit 1
}

echo "Installing or reconciling K3s through Azure VM Run Command."
K3S_INSTALL_RESPONSE="$(az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_VM_NAME" \
  --command-id RunShellScript \
  --scripts "
set -eu
install -d -m 0755 /etc/rancher/k3s
cat >/etc/rancher/k3s/config.yaml <<EOF
tls-san:
  - 127.0.0.1
  - ${VM_PRIVATE_IP}
write-kubeconfig-mode: \"0600\"
disable:
  - traefik
EOF
if command -v k3s >/dev/null 2>&1; then
  systemctl enable --now k3s
  systemctl restart k3s
else
  if ! curl -sfI --max-time 20 https://get.k3s.io >/dev/null 2>&1; then
    printf 'K3S_NO_OUTBOUND\n'
    exit 1
  fi
  curl -sfL https://get.k3s.io --output /tmp/install-k3s.sh
  sh /tmp/install-k3s.sh
  rm -f /tmp/install-k3s.sh
fi
systemctl is-active --quiet k3s
printf 'K3S_INSTALL_OK\n'
" \
  --output json)"
readonly K3S_INSTALL_RESPONSE
if jq -r '.value[]?.message // empty' <<<"$K3S_INSTALL_RESPONSE" |
  grep -qx 'K3S_NO_OUTBOUND'; then
  echo "The K3s VM has no outbound internet access, so the installer could not be downloaded." >&2
  echo "Azure is retiring implicit default outbound access; subnets created by newer API" >&2
  echo "versions are private by default and need an explicit outbound method." >&2
  echo "Re-run with a NAT gateway: K3S_ENABLE_NAT_GATEWAY=true bash resources/prepare-k3s-azure-vm.sh" >&2
  echo "If an Azure Policy denies default outbound access, the NAT gateway is required." >&2
  exit 1
fi
jq -r '.value[]?.message // empty' <<<"$K3S_INSTALL_RESPONSE" |
  grep -qx 'K3S_INSTALL_OK' || {
  echo "K3s guest installation did not return its success marker." >&2
  echo "Inspect Azure VM Run Command status and outbound access from the private VM." >&2
  exit 1
}

retrieve_kubeconfig() {
  local encoded_length
  local length_response
  local start
  local end
  local response
  local chunk
  local encoded_file
  local decoded_file
  local current_context

  install -d -m 0700 "$(dirname "$K3S_KUBECONFIG")"
  encoded_file="$(mktemp)"
  decoded_file="$(mktemp)"
  chmod 0600 "$encoded_file" "$decoded_file"
  TEMP_FILES+=("$encoded_file" "$decoded_file")

  length_response="$(az vm run-command invoke \
    --resource-group "$RESOURCE_GROUP" \
    --name "$K3S_VM_NAME" \
    --command-id RunShellScript \
    --scripts 'set -eu; encoded="$(base64 -w0 /etc/rancher/k3s/k3s.yaml)"; printf "K3S_LENGTH:%s\n" "${#encoded}"' \
    --output json)"
  encoded_length="$(jq -r '.value[]?.message // empty' <<<"$length_response" |
    sed -n 's/^K3S_LENGTH:\([0-9][0-9]*\)$/\1/p' |
    tail -n 1)"
  is_integer "$encoded_length" && ((encoded_length > 0 && encoded_length <= 65536)) || {
    echo "Could not determine a safe K3s kubeconfig length from Run Command." >&2
    return 1
  }

  : >"$encoded_file"
  for ((start = 1; start <= encoded_length; start += KUBECONFIG_CHUNK_SIZE)); do
    end=$((start + KUBECONFIG_CHUNK_SIZE - 1))
    echo "Retrieving protected kubeconfig chunk at offset ${start}."
    response="$(az vm run-command invoke \
      --resource-group "$RESOURCE_GROUP" \
      --name "$K3S_VM_NAME" \
      --command-id RunShellScript \
      --scripts "set -eu; printf 'K3S_CHUNK_BEGIN\n'; base64 -w0 /etc/rancher/k3s/k3s.yaml | cut -c ${start}-${end}; printf '\nK3S_CHUNK_END\n'" \
      --output json)"
    chunk="$(jq -r '.value[]?.message // empty' <<<"$response" |
      sed -n '/^K3S_CHUNK_BEGIN$/,/^K3S_CHUNK_END$/p' |
      sed '1d;$d' |
      tr -d '\r\n')"
    [[ "$chunk" =~ ^[A-Za-z0-9+/=]+$ ]] || {
      echo "Run Command returned an invalid kubeconfig chunk at offset ${start}." >&2
      return 1
    }
    printf '%s' "$chunk" >>"$encoded_file"
  done

  [[ "$(wc -c <"$encoded_file" | tr -d '[:space:]')" == "$encoded_length" ]] || {
    echo "Run Command kubeconfig retrieval was incomplete." >&2
    return 1
  }
  base64 --decode "$encoded_file" >"$decoded_file"
  grep -q '^apiVersion:' "$decoded_file"
  sed -E \
    "s#server: https://[^[:space:]]+#server: https://127.0.0.1:${K3S_LOCAL_PORT}#" \
    "$decoded_file" >"$encoded_file"
  install -m 0600 "$encoded_file" "$K3S_KUBECONFIG"
  current_context="$(KUBECONFIG="$K3S_KUBECONFIG" kubectl config current-context)"
  if [[ "$current_context" != "$K3S_CONTEXT" ]]; then
    KUBECONFIG="$K3S_KUBECONFIG" kubectl config rename-context \
      "$current_context" "$K3S_CONTEXT" >/dev/null
  fi
  rm -f "$encoded_file" "$decoded_file"
  register_k3s_context_in_default_kubeconfig
}

retrieve_kubeconfig

VM_POWER_STATE="$(az vm get-instance-view \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_VM_NAME" \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code | [0]" \
  --output tsv)"
readonly VM_POWER_STATE
[[ "$VM_POWER_STATE" == "PowerState/running" ]] || {
  echo "K3s VM power state is ${VM_POWER_STATE}." >&2
  exit 1
}

ensure_tunnel
validate_k3s

echo "K3s environment is healthy through Azure Bastion."
echo "Use it with: export KUBECONFIG=\"${K3S_KUBECONFIG}\""
echo "Reconnect with: bash resources/prepare-k3s-azure-vm.sh connect"
echo "Stop the tunnel with: bash resources/prepare-k3s-azure-vm.sh disconnect"
