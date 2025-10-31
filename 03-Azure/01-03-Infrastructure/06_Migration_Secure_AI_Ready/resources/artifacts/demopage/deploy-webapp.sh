#!/bin/bash
# =========================================================
# Web Server Deployment Script
# Converted from cloud.cfg
# =========================================================
# This script updates the system, installs required packages,
# deploys a demo web page, and starts the web server.
# =========================================================

set -e

echo "=========================================="
echo "🚀 Starting Web Server Deployment"
echo "=========================================="

# --- Step 1: Update and upgrade packages ---
#echo "📦 Updating system packages..."
sudo apt update -y
#sudo apt upgrade -y

# --- Step 2: Install required packages ---
echo "🧰 Installing required packages..."
# Note: 'httpd' is Apache on RHEL; on Ubuntu it's 'apache2'
if ! command -v apache2 >/dev/null 2>&1; then
    sudo apt install -y apache2 samba-client wget
else
    echo "✅ Apache already installed."
fi

# --- Step 3: Download demo web content ---
echo "🌐 Downloading demo web files..."
sudo mkdir -p /var/www/html

sudo wget -q https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage/index.html -O /var/www/html/index.html
sudo wget -q https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage/GitHub_Logo.png -O /var/www/html/GitHub_Logo.png
sudo wget -q https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage/MSLogo.png -O /var/www/html/MSLogo.png
sudo wget -q https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage/MSicon.png -O /var/www/html/MSicon.png
sudo wget -q https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage/github-mark.png -O /var/www/html/github-mark.png
sudo wget -q https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage/stylesheet.css -O /var/www/html/stylesheet.css

# --- Step 4: Replace <HOSTNAME> placeholder ---
echo "🖋️ Customizing index.html with system hostname..."
sudo sed -i "s/<HOSTNAME>/$(hostname)/g" /var/www/html/index.html

# --- Step 5: Enable and start web server ---
echo "🕹️ Enabling and starting Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

# --- Step 6: Display status and access info ---
echo "=========================================="
echo "✅ Deployment Complete!"
echo "🌍 Access your web page at: http://$(hostname -I | awk '{print $1}')/"
echo "=========================================="
