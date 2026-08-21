# Prepare private K3s through Azure Bastion

The default Local environment is single-node K3s on a private Ubuntu VM. It represents
self-managed on-premises or edge Kubernetes without requiring participant compute.
The VM has no public IP and no inbound Internet rules.

## Architecture

The preparation script creates or reuses:

- VNet `vnet-adaptive-apps` (`10.42.0.0/16`)
- Workload subnet `snet-k3s` (`10.42.0.0/24`)
- Required `AzureBastionSubnet` (`10.42.1.0/26`)
- NIC NSG `nsg-adaptive-apps-k3s`
- Private Ubuntu VM `vm-adaptive-apps-k3s`
- Standard static public IP `pip-adaptive-apps-bastion` for Azure Bastion only
- Standard host `bas-adaptive-apps` with native client tunneling enabled
- NAT gateway `natgw-adaptive-apps` and its Standard static public IP
  `pip-adaptive-apps-nat` for outbound access only

The VM NSG allows TCP 22 and 6443 only from `AzureBastionSubnet`, then explicitly denies
all other inbound traffic. K3s installation and kubeconfig retrieval use Azure VM Run
Command, so initial setup does not depend on SSH. Port 22 remains available only through
Bastion for approved Linux troubleshooting.

Azure Bastion Standard has a managed public endpoint, but the target VM remains private.
An enterprise with stricter requirements can substitute Azure Bastion Premium with its
private-only deployment capability. That substitution requires platform-owned networking
and is not the workshop default.

## Outbound internet access

The VM has no public IP and no inbound internet exposure, but it still needs *outbound*
access to install K3s from `get.k3s.io` and to pull container images.

Azure is retiring implicit default outbound access. For API versions released after
2026-03-31, new virtual networks default to private subnets, where a VM has no outbound
path at all unless an explicit method is configured. The behavior therefore depends on
the Azure CLI version that creates the subnet, not on the calendar date.

The script does not rely on the platform default. It selects one of two explicit
postures:

| Posture | How to select | Behavior | Cost |
| --- | --- | --- | --- |
| NAT gateway | default | Keeps `snet-k3s` private and attaches `natgw-adaptive-apps` with a Standard public IP. The NAT public IP is the only egress address. | Hourly NAT gateway charge plus per-GB data processing |
| Default outbound access, set explicitly | `K3S_ENABLE_NAT_GATEWAY=false` | Sets `defaultOutboundAccess=true` on `snet-k3s`, so the subnet keeps a working outbound path even under a newer CLI. | None |

```bash
export K3S_ENABLE_NAT_GATEWAY=false
bash resources/prepare-k3s-azure-vm.sh
```

The NAT gateway is the default because it is explicit, survives the retirement of default
outbound access, and provides a deterministic egress IP that a firewall can allowlist.
The subnet is kept private on purpose: a nonprivate subnet can still receive a
platform-assigned fallback outbound IP alongside the NAT gateway, which would defeat the
deterministic egress address.

Choose `K3S_ENABLE_NAT_GATEWAY=false` only to avoid the NAT gateway cost, and only where
Azure Policy still permits default outbound access.

If the subnet posture changes on an existing deployment, the script reconciles it and
restarts the VM, because both adding and removing a platform-assigned outbound IP only
take effect after the VM is deallocated and started again. When the installer still
cannot reach the internet, the script fails with an explicit message instead of a generic
K3s error.

## Provision and connect

From the Adaptive Apps MicroHack root:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
export AZURE_LOCATION="westeurope"
export RESOURCE_GROUP="rg-adaptive-apps"

bash resources/prepare-k3s-azure-vm.sh
```

The default `provision` mode:

1. Reconciles networking, Bastion, the private VM, and least-privilege NSG rules.
2. Installs K3s through Run Command with Traefik disabled.
3. Retrieves kubeconfig in bounded base64 chunks without printing cluster credentials.
4. Writes `~/.kube/adaptive-apps-k3s.yaml` with mode `0600`.
5. Rewrites the API endpoint to `https://127.0.0.1:16443`.
6. Starts a persistent `az network bastion tunnel` process.
7. Validates `/readyz` and node readiness.

Useful optional variables:

| Variable | Default |
| --- | --- |
| `VNET_NAME` / `VNET_PREFIX` | `vnet-adaptive-apps` / `10.42.0.0/16` |
| `K3S_SUBNET_NAME` / `K3S_SUBNET_PREFIX` | `snet-k3s` / `10.42.0.0/24` |
| `BASTION_SUBNET_PREFIX` | `10.42.1.0/26` |
| `K3S_VM_NAME` / `K3S_VM_SIZE` | `vm-adaptive-apps-k3s` / `Standard_D4s_v5` |
| `BASTION_NAME` | `bas-adaptive-apps` |
| `BASTION_PUBLIC_IP_NAME` | `pip-adaptive-apps-bastion` |
| `K3S_LOCAL_PORT` | `16443` |
| `K3S_KUBECONFIG` | `~/.kube/adaptive-apps-k3s.yaml` |

Use nonoverlapping CIDRs that comply with the subscription's network policy. The script
will not resize or move existing subnets. It also refuses to reuse an older K3s VM that
still has a public IP; remove the old VM/NIC/public IP or choose new VM and NIC names.

## Tunnel lifecycle

The tunnel runs independently of the provisioning shell but ends when the devcontainer
stops or rebuilds. Reconnect without provisioning:

```bash
export AZURE_SUBSCRIPTION="<subscription-id>"
bash resources/prepare-k3s-azure-vm.sh connect
```

Inspect or stop only the recorded tunnel:

```bash
bash resources/prepare-k3s-azure-vm.sh status
bash resources/prepare-k3s-azure-vm.sh disconnect
```

PID and log files are stored with restrictive permissions under
`~/.kube/adaptive-apps-bastion/`. Stale PIDs are removed safely. The script verifies the
recorded command line before sending `SIGTERM` and never kills by process name.

If localhost port 16443 is already occupied, choose a different unprivileged port before
both provisioning and later reconnects:

```bash
export K3S_LOCAL_PORT=26443
```

## Use and validate K3s

```bash
export KUBECONFIG="$HOME/.kube/adaptive-apps-k3s.yaml"
kubectl config use-context k3s-azure-vm
kubectl get --raw="/readyz"
kubectl wait --for=condition=Ready nodes --all --timeout=5m
kubectl get nodes -o wide
```

The Bastion tunnel forwards only localhost TCP 16443 to the private VM's Kubernetes API.
It does not expose the VM, workloads, HTTP, or HTTPS to the Internet. Access a Kubernetes
or Radius service with `kubectl port-forward`; that traffic travels through the API
tunnel.

## Permissions and troubleshooting

Participants need permission to create and update the resource group, VNet, subnets,
NIC, NSG, VM, Bastion host, and Bastion public IP. They also need VM Run Command and
Bastion tunnel actions. A Contributor role normally covers creation; delegated
environments may additionally require Network Contributor on the VNet and an approved
role containing `Microsoft.Network/bastionHosts/tunnels/action`.

| Symptom | Guidance |
| --- | --- |
| Azure Policy denies a resource | Use approved names, SKU, region, and CIDRs, or request the FDPO/platform exemption. Do not weaken the VM NSG. |
| Bastion creation is denied | Confirm Standard Bastion and its managed public IP are allowed, and verify Network Contributor/Bastion permissions. |
| Tunnel exits before becoming ready | Read `~/.kube/adaptive-apps-bastion/tunnel.log`; confirm Bastion is `Succeeded`, native tunneling is enabled, and the VM is running. |
| Local port is occupied | Stop the known owner or set a different `K3S_LOCAL_PORT`; the script will not kill an unrecorded process. |
| `kubectl` cannot reach 127.0.0.1 | Run `connect`, confirm `status`, and verify the kubeconfig local port matches `K3S_LOCAL_PORT`. |
| Existing VM has a public IP | Follow the script's migration message. It deliberately refuses to leave the legacy public topology in place. |
| K3s installer cannot be downloaded | The subnet has no outbound path. Confirm the NAT gateway exists and is attached to `snet-k3s`, or re-run with `K3S_ENABLE_NAT_GATEWAY=false` where policy still allows default outbound access. |

JIT access is not used. JIT only opens an NSG rule for a limited time; it does not create
a network route to a private VM. RDP is irrelevant to this Linux VM. Bastion provides the
private route, while SSH is an optional Linux management protocol.

## Cost and cleanup

Azure Bastion billing starts when the host is deployed and continues even when no tunnel
is active. The NAT gateway also bills hourly, plus per-GB data processing. After the
workshop:

```bash
bash resources/prepare-k3s-azure-vm.sh disconnect
az network bastion delete \
  --resource-group "$RESOURCE_GROUP" \
  --name bas-adaptive-apps \
  --yes
az network public-ip delete \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-adaptive-apps-bastion
```

The NAT gateway is deployed by default and bills hourly. Remove it and its public IP as
well:

```bash
az network nat gateway delete \
  --resource-group "$RESOURCE_GROUP" \
  --name natgw-adaptive-apps
az network public-ip delete \
  --resource-group "$RESOURCE_GROUP" \
  --name pip-adaptive-apps-nat
```

If the resource group is dedicated to this MicroHack and its contents have been reviewed,
the coach can remove the entire group separately. The script does not automate deletion.

K3s can optionally be connected to Azure Arc by following
[Prepare an Azure Arc-enabled cluster](prepare-arc.md). Establish the Bastion API tunnel
before running Arc commands that access the private Kubernetes API. Radius is installed
in Challenge 02.

## References

- [Deploy Azure Bastion with Azure CLI](https://learn.microsoft.com/azure/bastion/create-host-cli)
- [Configure Bastion native-client connections](https://learn.microsoft.com/azure/bastion/native-client)
- [Azure Bastion NSG guidance](https://learn.microsoft.com/azure/bastion/bastion-nsg)
- [Azure CLI Bastion reference](https://learn.microsoft.com/cli/azure/network/bastion)
- [Default outbound access in Azure](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access)
- [Design virtual networks with NAT gateway](https://learn.microsoft.com/azure/nat-gateway/nat-gateway-resource)
