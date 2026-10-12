#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR: Adaptive Apps tool installation failed at line ${LINENO}." >&2' ERR

readonly KUBECTL_VERSION="v1.36.3"
readonly HELM_VERSION="v3.21.4"
readonly RADIUS_VERSION="v0.60.0"
readonly YQ_VERSION="v4.53.4"
readonly BICEP_VERSION="v0.46.1"
readonly BASTION_EXTENSION_VERSION="1.4.3"

[[ "$(uname -s)" == "Linux" ]] || {
  echo "Use a Linux Console worker or the Adaptive Apps devcontainer." >&2
  exit 1
}
for command_name in az curl tar jq awk sha256sum install; do
  command -v "$command_name" >/dev/null || {
    echo "Required host tool is missing: ${command_name}. Install it before running this installer." >&2
    exit 1
  }
done
case "$(uname -m)" in
  x86_64) ARCH=amd64; BICEP_PLATFORM=linux-x64 ;;
  aarch64 | arm64) ARCH=arm64; BICEP_PLATFORM=linux-arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

retry() {
  local attempts="$1" count=1
  shift
  until "$@"; do
    if ((count >= attempts)); then
      return 1
    fi
    count=$((count + 1))
    sleep 2
  done
}

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
install -d "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

retry 3 curl --fail --location --silent --show-error \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
  --output "$temporary_directory/kubectl"
checksum="$(retry 3 curl --fail --location --silent --show-error \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256")"
printf '%s  %s\n' "$checksum" "$temporary_directory/kubectl" | sha256sum --check
install -m 0755 "$temporary_directory/kubectl" "$HOME/.local/bin/kubectl"

retry 3 curl --fail --location --silent --show-error \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
  --output "$temporary_directory/helm.tgz"
checksum="$(retry 3 curl --fail --location --silent --show-error \
  "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum" | awk '{print $1}')"
printf '%s  %s\n' "$checksum" "$temporary_directory/helm.tgz" | sha256sum --check
tar -xzf "$temporary_directory/helm.tgz" --directory "$temporary_directory"
install -m 0755 "$temporary_directory/linux-${ARCH}/helm" "$HOME/.local/bin/helm"

retry 3 curl --fail --location --silent --show-error \
  "https://raw.githubusercontent.com/radius-project/radius/${RADIUS_VERSION}/deploy/install.sh" \
  --output "$temporary_directory/install-radius.sh"
bash "$temporary_directory/install-radius.sh" --version "$RADIUS_VERSION" --install-dir "$HOME/.local/bin"

yq_asset="yq_linux_${ARCH}"
retry 3 curl --fail --location --silent --show-error \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${yq_asset}" \
  --output "$temporary_directory/yq"
checksums="$(retry 3 curl --fail --location --silent --show-error \
  "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums")"
checksum="$(awk -v asset="$yq_asset" '$1 == asset {print $19}' <<<"$checksums")"
[[ -n "$checksum" ]] || {
  echo "No SHA-256 checksum found for ${yq_asset}." >&2
  exit 1
}
printf '%s  %s\n' "$checksum" "$temporary_directory/yq" | sha256sum --check
install -m 0755 "$temporary_directory/yq" "$HOME/.local/bin/yq"

retry 3 az extension add --name bastion --version "$BASTION_EXTENSION_VERSION" \
  --upgrade --yes --allow-preview false --output none
retry 3 az bicep install --version "$BICEP_VERSION" --target-platform "$BICEP_PLATFORM"
az network bastion tunnel --help >/dev/null
az bicep version
kubectl version --client
helm version --short
rad version
yq --version
