#!/bin/sh
set -eu

source_root="https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage"
web_root="/var/www/html"
assets="index.html stylesheet.css GitHub_Logo.png MSLogo.png MSicon.png"
staging_root="$(mktemp -d)"
trap 'rm -rf "$staging_root"' EXIT

if ! command -v apache2 >/dev/null 2>&1 ||
   ! command -v wget >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 wget
fi

for asset in $assets; do
  wget --quiet --https-only --timeout=30 --tries=3 \
    --output-document "$staging_root/$asset" "$source_root/$asset"
  test -s "$staging_root/$asset" || {
    echo "Downloaded asset is empty: $asset" >&2
    exit 1
  }
done

hostname_value="$(hostname)"
sed -i \
  -e "s|<HOSTNAME>|$hostname_value|g" \
  -e 's|<PLATFORM>|Ubuntu Linux|g' \
  -e 's|<WEB_SERVER>|Apache|g' \
  "$staging_root/index.html"

if grep -Eq '<(HOSTNAME|PLATFORM|WEB_SERVER)>' "$staging_root/index.html"; then
  echo "One or more template tokens remain in index.html." >&2
  exit 1
fi

sudo mkdir -p "$web_root"
sudo find "$web_root" -mindepth 1 -delete
for asset in $assets; do
  sudo install -m 0644 "$staging_root/$asset" "$web_root/$asset"
done

deployed_count="$(sudo find "$web_root" -mindepth 1 -maxdepth 1 -type f | wc -l)"
if [ "$deployed_count" -ne 5 ]; then
  echo "The Apache web root does not contain exactly the expected static assets." >&2
  exit 1
fi

sudo systemctl enable --now apache2
wget --quiet --spider --timeout=15 http://127.0.0.1/
