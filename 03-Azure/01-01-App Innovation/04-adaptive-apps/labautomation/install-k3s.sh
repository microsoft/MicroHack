#!/usr/bin/env sh
# Executed as root by Azure VM Run Command; no kubeconfig or token is returned.
set -eu
K3S_VERSION="${K3S_VERSION:-v1.33.13+k3s1}"
printf '%s\n' "$K3S_VERSION" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$' || {
  echo "K3S_VERSION must be an exact release such as v1.33.13+k3s1." >&2
  exit 2
}
if command -v k3s >/dev/null 2>&1; then
  installed_version="$(k3s --version)"
  installed_version="${installed_version#k3s version }"
  installed_version="${installed_version%% *}"
  if [ "$installed_version" != "$K3S_VERSION" ]; then
    printf 'K3S_VERSION_MISMATCH: Existing K3s version %s does not match required %s. Automatic version changes are not supported. Use a fresh lab VM.\n' "$installed_version" "$K3S_VERSION" >&2
    exit 1
  fi
fi
install -d -m 0700 /etc/rancher/k3s
if ! command -v k3s >/dev/null 2>&1; then
  cat >/etc/rancher/k3s/config.yaml <<'EOF'
tls-san:
  - 127.0.0.1
write-kubeconfig-mode: "0600"
cluster-cidr: 10.52.0.0/16
service-cidr: 10.53.0.0/16
disable:
  - traefik
EOF
  cd /etc/rancher/k3s
  trap 'rm -f /etc/rancher/k3s/install-console-k3s.sh' EXIT
  curl --fail --silent --show-error --location --retry 3 https://get.k3s.io --output install-console-k3s.sh
  INSTALL_K3S_VERSION="$K3S_VERSION" sh install-console-k3s.sh
fi
systemctl enable --now k3s
for attempt in $(seq 1 60); do
  if k3s kubectl get --raw=/readyz >/dev/null 2>&1; then
    k3s kubectl wait --for=condition=Ready nodes --all --timeout=5m
    printf 'ADAPTIVE_K3S_READY\n'
    exit 0
  fi
  sleep 5
done
echo 'K3s did not become ready. Inspect systemctl status k3s and outbound NAT.' >&2
exit 1
