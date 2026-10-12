#!/usr/bin/env sh
# Executed as root by Azure VM Run Command; no kubeconfig or token is returned.
set -eu
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
  INSTALL_K3S_CHANNEL=stable sh install-console-k3s.sh
fi
systemctl enable --now k3s
for attempt in $(seq 1 60); do
  if k3s kubectl get --raw=/readyz >/dev/null 2>&1; then
    printf 'ADAPTIVE_K3S_READY\n'
    exit 0
  fi
  sleep 5
done
echo 'K3s did not become ready. Inspect systemctl status k3s and outbound NAT.' >&2
exit 1
