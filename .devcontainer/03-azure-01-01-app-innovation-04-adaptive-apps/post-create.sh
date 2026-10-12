#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR: Adaptive Apps devcontainer setup failed at line ${LINENO}." >&2' ERR

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
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$repository_root/03-Azure/01-01-App Innovation/04-adaptive-apps/resources/install-console-tools.sh"
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
