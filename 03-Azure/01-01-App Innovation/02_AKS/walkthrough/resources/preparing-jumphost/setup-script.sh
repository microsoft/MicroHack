set -e

# Update and install prerequisites
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF


# Update and install prerequisites
sudo apt update && sudo apt install -y git gh gpg ca-certificates curl apt-transport-https software-properties-common docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# -------------------------------
# Add Azure CLI
# -------------------------------
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# -------------------------------
# Add Kubernetes (kubectl)
# -------------------------------
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# -------------------------------
# Add Helm
# -------------------------------
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

# -------------------------------
# Add K9s
# -------------------------------
wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb
sudo apt install ./k9s_linux_amd64.deb
rm k9s_linux_amd64.deb

# -------------------------------
# Enable kubectl autocomplete
# -------------------------------
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.profile
echo "alias k=kubectl" >> ~/.profile
echo "complete -o default -F __start_kubectl k" >> ~/.profile

# Add current user to docker group
sudo usermod -aG docker $USER

# Final upgrade and cleanup
sudo NEEDRESTART_MODE=l apt-get dist-upgrade -y
sudo apt autoremove -y

echo "✅ Setup completed successfully!"