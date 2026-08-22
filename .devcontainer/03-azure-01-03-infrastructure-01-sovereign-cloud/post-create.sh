#!/usr/bin/env bash
set -euo pipefail

retry() {
  local attempts=$1
  shift
  local count=1
  until "$@"; do
    if [[ $count -ge $attempts ]]; then
      return 1
    fi
    count=$((count + 1))
    sleep 2
  done
}

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)
    BICEP_PLATFORM="linux-x64"
    YQ_ARCH="amd64"
    ;;
  aarch64|arm64)
    BICEP_PLATFORM="linux-arm64"
    YQ_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

mkdir -p "$HOME/.local/bin"
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

if ! command -v jq >/dev/null 2>&1; then
  retry 3 sudo apt-get update
  retry 3 sudo apt-get install -y jq
fi

# Azure CLI (fallback when the devcontainer feature is unavailable)
if ! command -v az >/dev/null 2>&1; then
  AZ_INSTALL_SCRIPT="$(mktemp)"
  retry 3 curl -fsSL https://aka.ms/InstallAzureCLIDeb -o "$AZ_INSTALL_SCRIPT"
  sudo bash "$AZ_INSTALL_SCRIPT"
  rm -f "$AZ_INSTALL_SCRIPT"
fi

# kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION="$(retry 3 curl -fsSL https://dl.k8s.io/release/stable.txt)"
  retry 3 curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${YQ_ARCH}/kubectl" -o "$HOME/.local/bin/kubectl"
  chmod +x "$HOME/.local/bin/kubectl"
fi

# Helm
if ! command -v helm >/dev/null 2>&1; then
  HELM_ARCH="$YQ_ARCH"
  HELM_VERSION="$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name || true)"
  if [[ -z "${HELM_VERSION}" || "${HELM_VERSION}" == "null" ]]; then
    HELM_VERSION="v3.16.4"
    echo "Helm latest lookup failed; falling back to ${HELM_VERSION}."
  fi
  TMP_DIR="$(mktemp -d)"
  retry 3 curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" -o "$TMP_DIR/helm.tgz"
  tar -xzf "$TMP_DIR/helm.tgz" -C "$TMP_DIR"
  install -m 0755 "$TMP_DIR/linux-${HELM_ARCH}/helm" "$HOME/.local/bin/helm"
  rm -rf "$TMP_DIR"
fi

# Radius CLI (rad)
if ! command -v rad >/dev/null 2>&1; then
  wget -q "https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh" -O - | /bin/bash
fi
if [[ -x "$HOME/.rad/bin/rad" ]]; then
  ln -sf "$HOME/.rad/bin/rad" "$HOME/.local/bin/rad"
fi

# yq for YAML processing used in scripting/tutorials
if ! command -v yq >/dev/null 2>&1; then
  retry 3 curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}" -o "$HOME/.local/bin/yq"
  chmod +x "$HOME/.local/bin/yq"
fi

# k3d for local k3s workflows (only when Docker is available)
K3D_SKIPPED=0
if command -v docker >/dev/null 2>&1; then
  if ! command -v k3d >/dev/null 2>&1; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
  fi
else
  K3D_SKIPPED=1
  echo "Skipping k3d install: docker CLI/socket not available in this container runtime."
fi

# Standalone Bicep CLI for authoring and PowerShell workflows
if ! command -v bicep >/dev/null 2>&1; then
  retry 3 curl -fsSL "https://github.com/Azure/bicep/releases/latest/download/bicep-${BICEP_PLATFORM}" -o "$HOME/.local/bin/bicep"
  chmod +x "$HOME/.local/bin/bicep"
fi

# Azure CLI manages its own Bicep instance for az deployment commands.
retry 3 az bicep install --target-platform "$BICEP_PLATFORM"

echo "Installed tool versions:"
for cmd in az kubectl helm rad bicep k3d rustc cargo jq yq pwsh; do
  if [[ "$cmd" == "k3d" && "$K3D_SKIPPED" -eq 1 ]]; then
    echo "k3d: skipped (docker unavailable)"
    continue
  fi

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd: not found"
    continue
  fi

  case "$cmd" in
    az)
      az version --query '"azure-cli"' -o tsv 2>/dev/null | sed 's/^/azure-cli: /' || true
      ;;
    kubectl)
      kubectl version --client 2>/dev/null | head -n 2 || true
      ;;
    helm)
      helm version --short 2>/dev/null || true
      ;;
    rad)
      rad version 2>/dev/null | head -n 4 || true
      ;;
    bicep)
      bicep --version 2>/dev/null || true
      ;;
    k3d)
      k3d version 2>/dev/null | head -n 1 || true
      ;;
    rustc|cargo|jq|yq|pwsh)
      "$cmd" --version 2>/dev/null | head -n 1 || true
      ;;
  esac
done