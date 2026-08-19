#!/usr/bin/env bash
set -euo pipefail

for command_name in az curl grep kubectl sed ssh; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Required command not found: $command_name" >&2
    exit 1
  }
done

: "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION to the target subscription ID.}"
AZURE_LOCATION="${AZURE_LOCATION:-westeurope}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-adaptive-apps}"
K3S_VM_NAME="${K3S_VM_NAME:-vm-adaptive-apps-k3s}"
K3S_VM_SIZE="${K3S_VM_SIZE:-Standard_D4s_v5}"
K3S_ADMIN_USERNAME="${K3S_ADMIN_USERNAME:-azureuser}"
K3S_KUBECONFIG="${K3S_KUBECONFIG:-$HOME/.kube/adaptive-apps-k3s.yaml}"
K3S_CONTEXT="${K3S_CONTEXT:-k3s-azure-vm}"

if [[ -z "${ADMIN_CIDR:-}" ]]; then
  ADMIN_CIDR="$(curl --fail --silent --show-error https://api.ipify.org)/32"
  echo "ADMIN_CIDR was not set; using ${ADMIN_CIDR}."
fi

az account show >/dev/null 2>&1 || az login
az account set --subscription "$AZURE_SUBSCRIPTION"
az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION" --output none

if ! az vm show -g "$RESOURCE_GROUP" -n "$K3S_VM_NAME" >/dev/null 2>&1; then
  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$K3S_VM_NAME" \
    --location "$AZURE_LOCATION" \
    --image Ubuntu2204 \
    --size "$K3S_VM_SIZE" \
    --admin-username "$K3S_ADMIN_USERNAME" \
    --authentication-type ssh \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    --nsg-rule NONE \
    --os-disk-size-gb 64 \
    --storage-sku StandardSSD_LRS \
    --output none
else
  az vm start -g "$RESOURCE_GROUP" -n "$K3S_VM_NAME" --output none
fi

NIC_ID="$(az vm show -g "$RESOURCE_GROUP" -n "$K3S_VM_NAME" --query "networkProfile.networkInterfaces[0].id" -o tsv)"
NSG_ID="$(az network nic show --ids "$NIC_ID" --query networkSecurityGroup.id -o tsv)"
[[ -n "$NSG_ID" ]] || {
  echo "The K3s VM network interface has no network security group." >&2
  exit 1
}
NSG_NAME="${NSG_ID##*/}"

create_rule() {
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "$1" \
    --priority "$2" \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --source-address-prefixes "$3" \
    --destination-port-ranges "$4" \
    --output none
}

create_rule AllowSshFromAdmin 900 "$ADMIN_CIDR" 22
create_rule AllowKubernetesApiFromAdmin 910 "$ADMIN_CIDR" 6443
create_rule AllowHttp 1000 Internet 80
create_rule AllowHttps 1010 Internet 443

PUBLIC_IP="$(az vm show -g "$RESOURCE_GROUP" -n "$K3S_VM_NAME" --show-details --query publicIps -o tsv)"
[[ -n "$PUBLIC_IP" ]] || {
  echo "The K3s VM has no public IP address." >&2
  exit 1
}

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$K3S_VM_NAME" \
  --command-id RunShellScript \
  --scripts "
set -eu
mkdir -p /etc/rancher/k3s
cat >/etc/rancher/k3s/config.yaml <<EOF
tls-san:
  - ${PUBLIC_IP}
write-kubeconfig-mode: \"0644\"
disable:
  - traefik
EOF
if command -v k3s >/dev/null 2>&1; then
  systemctl enable --now k3s
  systemctl restart k3s
else
  curl -sfL https://get.k3s.io | sh -
fi
systemctl is-active --quiet k3s
" \
  --output none

for attempt in {1..30}; do
  if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
    "${K3S_ADMIN_USERNAME}@${PUBLIC_IP}" \
    "sudo systemctl is-active --quiet k3s" 2>/dev/null; then
    break
  fi
  [[ "$attempt" -lt 30 ]] || {
    echo "Timed out waiting for SSH access to K3s." >&2
    exit 1
  }
  sleep 10
done

mkdir -p "$(dirname "$K3S_KUBECONFIG")"
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
  "${K3S_ADMIN_USERNAME}@${PUBLIC_IP}" \
  "sudo cat /etc/rancher/k3s/k3s.yaml" |
  sed "s/127.0.0.1/${PUBLIC_IP}/" >"$K3S_KUBECONFIG"
chmod 600 "$K3S_KUBECONFIG"

CURRENT_CONTEXT="$(KUBECONFIG="$K3S_KUBECONFIG" kubectl config current-context)"
if [[ "$CURRENT_CONTEXT" != "$K3S_CONTEXT" ]]; then
  KUBECONFIG="$K3S_KUBECONFIG" kubectl config rename-context \
    "$CURRENT_CONTEXT" "$K3S_CONTEXT" >/dev/null
fi

VM_POWER_STATE="$(az vm get-instance-view -g "$RESOURCE_GROUP" -n "$K3S_VM_NAME" \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].code | [0]" -o tsv)"
[[ "$VM_POWER_STATE" == "PowerState/running" ]] || {
  echo "K3s VM power state is $VM_POWER_STATE." >&2
  exit 1
}

KUBECONFIG="$K3S_KUBECONFIG" kubectl get --raw="/readyz" | grep -qx "ok"
KUBECONFIG="$K3S_KUBECONFIG" kubectl wait --for=condition=Ready nodes --all --timeout=10m
KUBECONFIG="$K3S_KUBECONFIG" kubectl get nodes -o wide

echo "K3s environment is healthy."
echo "Use it with: export KUBECONFIG=\"${K3S_KUBECONFIG}\""
