#!/usr/bin/env bash
set -euo pipefail
trap 'status=$?; echo "ERROR: Sovereign Cloud devcontainer setup failed at line ${LINENO}: ${BASH_COMMAND} (exit ${status})." >&2' ERR

readonly KUBECTL_VERSION="v1.36.3"
readonly HELM_VERSION="v3.21.4"
readonly RADIUS_VERSION="v0.60.0"
readonly YQ_VERSION="v4.53.4"
readonly BICEP_VERSION="v0.46.1"
readonly BASTION_EXTENSION_VERSION="1.4.3"

retry() {
  local attempts="$1"
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

case "$(uname -m)" in
  x86_64)
    readonly ARCH="amd64"
    readonly BICEP_PLATFORM="linux-x64"
    ;;
  aarch64|arm64)
    readonly ARCH="arm64"
    readonly BICEP_PLATFORM="linux-arm64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

for state_directory in "$HOME/.azure" "$HOME/.kube" "$HOME/.rad" "$HOME/.ssh"; do
  sudo install -d -m 0700 -o "$(id -u)" -g "$(id -g)" "$state_directory"
done

sudo apt-get update
sudo apt-get install --yes --no-install-recommends \
  ca-certificates \
  curl \
  git \
  jq \
  nodejs \
  npm \
  openssh-client \
  tar
sudo rm -rf /var/lib/apt/lists/*

mkdir -p "$HOME/.local/bin"
if ! grep -Fqx 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

configure_windows_worktree_shell() {
  local git_pointer="/workspaces/microhack/.git"
  local marker="# Sovereign Cloud Windows worktree prompt"

  if [[ ! -f "$git_pointer" ]] ||
    ! grep -Eq '^gitdir: [A-Za-z]:[/\\]' "$git_pointer"; then
    return
  fi

  if ! grep -Fqx "$marker" "$HOME/.bashrc"; then
    cat >>"$HOME/.bashrc" <<'EOF'

# Sovereign Cloud Windows worktree prompt
# The bound .git file points to Windows-only worktree metadata. Avoid probing it.
unset PROMPT_COMMAND
PS1='\u@\h:\w\$ '
EOF
  fi

  echo "Windows Git worktree detected. Repository-aware Git commands are unavailable"
  echo "inside this container; the MicroHack commands do not require them."
}

configure_git_safe_directories() {
  local safe_directory
  local -a safe_directories=()

  mapfile -t safe_directories < <(git config --global --get-all safe.directory 2>/dev/null || true)
  git config --global --unset-all safe.directory 2>/dev/null || true

  for safe_directory in "${safe_directories[@]}"; do
    if [[ "$safe_directory" != "/workspaces/microhack" ]] &&
      [[ "$safe_directory" == /* || "$safe_directory" == '~/'* || "$safe_directory" == '*' ]]; then
      git config --global --add safe.directory "$safe_directory"
    fi
  done

  git config --global --add safe.directory /workspaces/microhack
}

configure_windows_worktree_shell
configure_git_safe_directories

# Azure CLI (fallback when the devcontainer feature is unavailable)
if ! command -v az >/dev/null 2>&1; then
  AZ_INSTALL_SCRIPT="$(mktemp)"
  retry 3 curl -fsSL https://aka.ms/InstallAzureCLIDeb -o "$AZ_INSTALL_SCRIPT"
  sudo bash "$AZ_INSTALL_SCRIPT"
  rm -f "$AZ_INSTALL_SCRIPT"
fi

# kubectl
retry 3 curl --fail --location --silent --show-error \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
  --output "$HOME/.local/bin/kubectl"
KUBECTL_CHECKSUM="$(retry 3 curl --fail --location --silent --show-error \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256")"
printf '%s  %s\n' "$KUBECTL_CHECKSUM" "$HOME/.local/bin/kubectl" | sha256sum --check
chmod 0755 "$HOME/.local/bin/kubectl"

# Helm
HELM_TEMPORARY_DIRECTORY="$(mktemp -d)"
retry 3 curl --fail --location --silent --show-error \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
  --output "$HELM_TEMPORARY_DIRECTORY/helm.tgz"
HELM_CHECKSUM="$(retry 3 curl --fail --location --silent --show-error \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum" |
  awk '{ print $1 }')"
printf '%s  %s\n' "$HELM_CHECKSUM" "$HELM_TEMPORARY_DIRECTORY/helm.tgz" |
  sha256sum --check
tar -xzf "$HELM_TEMPORARY_DIRECTORY/helm.tgz" -C "$HELM_TEMPORARY_DIRECTORY"
install -m 0755 \
  "$HELM_TEMPORARY_DIRECTORY/linux-${ARCH}/helm" \
  "$HOME/.local/bin/helm"
rm -rf "$HELM_TEMPORARY_DIRECTORY"

# Radius CLI (rad)
retry 3 curl --fail --location --silent --show-error \
  "https://raw.githubusercontent.com/radius-project/radius/${RADIUS_VERSION}/deploy/install.sh" \
  --output /tmp/install-radius.sh
bash /tmp/install-radius.sh \
  --version "$RADIUS_VERSION" \
  --install-dir "$HOME/.local/bin"
rm -f /tmp/install-radius.sh

# yq for YAML processing used in scripting/tutorials
YQ_ASSET="yq_linux_${ARCH}"
retry 3 curl --fail --location --silent --show-error \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_ASSET}" \
  --output "$HOME/.local/bin/yq"
YQ_CHECKSUMS="$(retry 3 curl --fail --location --silent --show-error \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums")"
YQ_CHECKSUM="$(awk -v asset="$YQ_ASSET" '$1 == asset { print $19 }' <<<"$YQ_CHECKSUMS")"
[[ -n "$YQ_CHECKSUM" ]] || {
  echo "No SHA-256 checksum found for ${YQ_ASSET}." >&2
  exit 1
}
printf '%s  %s\n' "$YQ_CHECKSUM" "$HOME/.local/bin/yq" | sha256sum --check
chmod 0755 "$HOME/.local/bin/yq"

# Standalone Bicep CLI for authoring and PowerShell workflows
retry 3 curl --fail --location --silent --show-error \
  "https://github.com/Azure/bicep/releases/download/${BICEP_VERSION}/bicep-${BICEP_PLATFORM}" \
  --output "$HOME/.local/bin/bicep"
chmod 0755 "$HOME/.local/bin/bicep"

# Azure CLI manages its own Bicep instance for az deployment commands.
retry 3 az extension add \
  --name bastion \
  --version "$BASTION_EXTENSION_VERSION" \
  --upgrade \
  --yes \
  --allow-preview false \
  --output none
retry 3 az bicep install \
  --version "$BICEP_VERSION" \
  --target-platform "$BICEP_PLATFORM"

echo "Installed tool versions:"
MISSING_TOOLING=0
for cmd in az kubectl helm rad bicep node npm npx rustc cargo git jq yq pwsh ssh tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd: not found"
    MISSING_TOOLING=1
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
    node|npm|npx|rustc|cargo|jq|yq|pwsh)
      "$cmd" --version 2>/dev/null | head -n 1 || true
      ;;
  esac
done

if ! az bicep version >/dev/null 2>&1; then
  echo "Azure CLI Bicep: not found" >&2
  MISSING_TOOLING=1
fi

if ! az network bastion tunnel --help >/dev/null 2>&1; then
  echo "Azure CLI Bastion tunnel support: not found" >&2
  MISSING_TOOLING=1
else
  az extension show --name bastion --query version -o tsv | sed 's/^/bastion extension: /'
fi

if [[ "$MISSING_TOOLING" -ne 0 ]]; then
  echo "Devcontainer setup is incomplete. Rebuild the container or rerun post-create.sh." >&2
  exit 1
fi