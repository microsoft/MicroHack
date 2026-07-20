#!/bin/bash
# Install MicroHack prerequisite tools inside WSL Ubuntu
set -e

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package lists..."
apt-get update

echo "==> Installing git..."
apt-get install -y git ca-certificates curl apt-transport-https

echo "==> Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

echo "==> Installing kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
echo "    kubectl ${KUBECTL_VERSION} installed"

echo "==> Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ""
echo "==> All MicroHack prerequisite tools installed successfully!"
echo "    git:     $(git --version)"
echo "    az:      $(az version --query '\"azure-cli\"' -o tsv)"
echo "    kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "    helm:    $(helm version --short)"
