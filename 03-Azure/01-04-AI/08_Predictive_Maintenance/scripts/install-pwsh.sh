#!/bin/bash
# =============================================================================
# LOCAL DEVELOPMENT / TESTING ONLY
# =============================================================================
# This script installs PowerShell 7 (pwsh) for local test simulation of
# deploy-lab.ps1. It has NO RELATION to the production Hack Console / Hackbox
# provisioning platform (which already executes PowerShell natively in its
# runner environment) and is NOT needed by hackathon participants.
# =============================================================================

set -e

echo "🔍 Detecting architecture and latest PowerShell 7 release..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  PWSH_ARCH="x64" ;;
    aarch64) PWSH_ARCH="arm64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

INSTALL_DIR="/usr/local/share/powershell"
BIN_LINK="/usr/local/bin/pwsh"

# Fetch latest release tag from GitHub API or fallback to 7.4 LTS
LATEST_VERSION=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' || echo "7.4.6")
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="7.4.6"
fi

TARBALL_URL="https://github.com/PowerShell/PowerShell/releases/download/v${LATEST_VERSION}/powershell-${LATEST_VERSION}-linux-${PWSH_ARCH}.tar.gz"

echo "📦 Downloading PowerShell v${LATEST_VERSION} (${PWSH_ARCH})..."
TMP_DIR=$(mktemp -d)
curl -sSL "$TARBALL_URL" -o "$TMP_DIR/powershell.tar.gz"

echo "📂 Extracting to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -zxf "$TMP_DIR/powershell.tar.gz" -C "$INSTALL_DIR"
sudo chmod +x "$INSTALL_DIR/pwsh"

echo "🔗 Creating symlink at $BIN_LINK..."
sudo ln -sf "$INSTALL_DIR/pwsh" "$BIN_LINK"

rm -rf "$TMP_DIR"

echo "✅ PowerShell installed successfully!"
pwsh --version
