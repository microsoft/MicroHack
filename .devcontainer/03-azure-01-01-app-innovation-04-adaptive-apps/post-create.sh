#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR: Adaptive Apps devcontainer setup failed at line ${LINENO}." >&2' ERR

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
    if [[ "$count" -ge "$attempts" ]]; then
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
  aarch64 | arm64)
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
  local marker="# Adaptive Apps Windows worktree prompt"

  if [[ ! -f "$git_pointer" ]] ||
    ! grep -Eq '^gitdir: [A-Za-z]:[/\\]' "$git_pointer"; then
    return
  fi

  if ! grep -Fqx "$marker" "$HOME/.bashrc"; then
    cat >>"$HOME/.bashrc" <<'EOF'

# Adaptive Apps Windows worktree prompt
# The bound .git file points to Windows-only worktree metadata. Avoid probing it.
unset PROMPT_COMMAND
PS1='\u@\h:\w\$ '
EOF
  fi

  echo "Windows Git worktree detected. Repository-aware Git commands are unavailable"
  echo "inside this container; the MicroHack commands do not require them."
}

install_kubectl() {
  local checksum
  retry 3 curl --fail --location --silent --show-error \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    --output "$HOME/.local/bin/kubectl"
  checksum="$(retry 3 curl --fail --location --silent --show-error \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256")"
  printf '%s  %s\n' "$checksum" "$HOME/.local/bin/kubectl" | sha256sum --check
  chmod 0755 "$HOME/.local/bin/kubectl"
}

install_helm() {
  local checksum
  local temporary_directory
  temporary_directory="$(mktemp -d)"

  retry 3 curl --fail --location --silent --show-error \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
    --output "$temporary_directory/helm.tgz"
  checksum="$(retry 3 curl --fail --location --silent --show-error \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum" |
    awk '{ print $1 }')"
  printf '%s  %s\n' "$checksum" "$temporary_directory/helm.tgz" |
    sha256sum --check
  (
    cd "$temporary_directory"
    tar -xzf helm.tgz
  )
  install -m 0755 \
    "$temporary_directory/linux-${ARCH}/helm" \
    "$HOME/.local/bin/helm"
  rm -rf "$temporary_directory"
}

install_radius() {
  retry 3 curl --fail --location --silent --show-error \
    "https://raw.githubusercontent.com/radius-project/radius/${RADIUS_VERSION}/deploy/install.sh" \
    --output /tmp/install-radius.sh
  bash /tmp/install-radius.sh \
    --version "$RADIUS_VERSION" \
    --install-dir "$HOME/.local/bin"
  rm -f /tmp/install-radius.sh
}

install_yq() {
  local checksum
  local checksums
  local yq_asset="yq_linux_${ARCH}"

  retry 3 curl --fail --location --silent --show-error \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${yq_asset}" \
    --output "$HOME/.local/bin/yq"
  checksums="$(retry 3 curl --fail --location --silent --show-error \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums")"
  checksum="$(awk -v asset="$yq_asset" '$1 == asset { print $19 }' <<<"$checksums")"
  [[ -n "$checksum" ]] || {
    echo "No SHA-256 checksum found for ${yq_asset}." >&2
    return 1
  }
  printf '%s  %s\n' "$checksum" "$HOME/.local/bin/yq" | sha256sum --check
  chmod 0755 "$HOME/.local/bin/yq"
}

verify_tooling() {
  local command_name
  local missing=0

  echo
  echo "Adaptive Apps MicroHack tool verification:"
  for command_name in az kubectl helm rad git jq yq curl pwsh ssh tar; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "ERROR: required command not found: ${command_name}" >&2
      missing=1
    else
      printf '%-8s %s\n' "$command_name" "$(command -v "$command_name")"
    fi
  done

  if ! az bicep version >/dev/null 2>&1; then
    echo "ERROR: Azure CLI Bicep is not available." >&2
    missing=1
  else
    printf '%-8s %s\n' "bicep" "az bicep"
  fi
  if ! az network bastion tunnel --help >/dev/null 2>&1; then
    echo "ERROR: Azure CLI Bastion tunnel support is not available." >&2
    missing=1
  else
    printf '%-8s %s\n' "bastion" "$(az extension show --name bastion --query version --output tsv)"
  fi

  if [[ "$missing" -ne 0 ]]; then
    echo "Devcontainer setup is incomplete. Rebuild the container or rerun:" >&2
    echo "bash /workspaces/microhack/.devcontainer/03-azure-01-01-app-innovation-04-adaptive-apps/post-create.sh" >&2
    return 1
  fi
}

configure_windows_worktree_shell
install_kubectl
install_helm
install_radius
install_yq
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
verify_tooling

echo
echo "Adaptive Apps MicroHack tool versions:"
az version --query '"azure-cli"' --output tsv | sed 's/^/azure-cli: /'
az bicep version
kubectl version --client
helm version --short
rad version
pwsh --version
git --version
jq --version
yq --version
az extension show --name bastion --query version --output tsv | sed 's/^/bastion extension: /'
ssh -V

echo
echo "The container is ready. Sign in with 'az login' and select the lab subscription."
