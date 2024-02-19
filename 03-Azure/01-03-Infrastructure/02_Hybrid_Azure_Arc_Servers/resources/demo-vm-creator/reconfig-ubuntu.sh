#!/bin/sh

CURRENT_HOSTNAME=$(hostname)
sudo service walinuxagent stop
sudo waagent -deprovision -force
sudo rm -rf /var/lib/waagent
sudo hostnamectl set-hostname $CURRENT_HOSTNAME

sudo ufw --force enable
sudo ufw deny out from any to 169.254.169.254
sudo ufw default allow incoming