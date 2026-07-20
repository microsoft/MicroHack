#!/bin/bash
set -euo pipefail

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

# Install Docker (optional for some workloads)
# Note: k3s includes its own container runtime, so Docker is optional
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Install Docker without pinning containerd.io version, continue on error
apt-get install -y docker-ce docker-ce-cli containerd.io || echo "Docker installation failed, continuing with k3s (which includes its own container runtime)"

# Add admin user to docker group if docker was installed successfully
if command -v docker &> /dev/null; then
  usermod -aG docker ${admin_user}
fi

# Install K3s server (master node)
export INSTALL_K3S_VERSION=${k3s_version}
export K3S_TOKEN=${cluster_token}

# Install K3s with embedded etcd and disable traefik (we might want to use nginx-ingress)
# All cluster communication uses private IPs (workstations access via VNet, external via Bastion)
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --token $${K3S_TOKEN}

# Wait for K3s to be ready
while ! kubectl get nodes > /dev/null 2>&1; do
  echo "Waiting for K3s to be ready..."
  sleep 10
done

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Make kubectl accessible for admin user
mkdir -p /home/${admin_user}/.kube
cp /etc/rancher/k3s/k3s.yaml /home/${admin_user}/.kube/config
chown ${admin_user}:${admin_user} /home/${admin_user}/.kube/config

# Create a script to get the node token for workers
cat > /home/${admin_user}/get-node-token.sh << 'EOF'
#!/bin/bash
sudo cat /var/lib/rancher/k3s/server/node-token
EOF
chmod +x /home/${admin_user}/get-node-token.sh
chown ${admin_user}:${admin_user} /home/${admin_user}/get-node-token.sh

# Enable and start K3s
systemctl enable k3s
systemctl start k3s

echo "K3s master node setup completed!"