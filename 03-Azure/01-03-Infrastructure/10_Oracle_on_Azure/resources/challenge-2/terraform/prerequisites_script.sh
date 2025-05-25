#!/bin/sh
# install python 3.8.9 because ansible is not supported on 3.6 which comes along with Oracle Linux 8.10
echo "Installing python required packages gcc openssl-devel libffi-devel bzip2-devel wget nvme-cli"
sudo yum update -y
sudo yum install -y gcc openssl-devel libffi-devel bzip2-devel wget make
echo "Downloading Python 3.8.9"
cd /opt
sudo wget https://www.python.org/ftp/python/3.8.9/Python-3.8.9.tgz
sudo tar xzvf Python-3.8.9.tgz
echo "Installing Python 3.8.9"
cd Python-3.8.9/
sudo ./configure --enable-optimizations
sudo make altinstall
sudo ln -sf /usr/local/bin/python3.8 /usr/bin/python3
python3 --version

# install oracle software prerequisites
sudo curl -o oracle-database-preinstall-19c-1.0-2.el8.x86_64.rpm https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/getPackage/oracle-database-preinstall-19c-1.0-2.el8.x86_64.rpm
sudo yum localinstall -y ./oracle-database-preinstall-19c-1.0-2.el8.x86_64.rpm 
sudo yum install -y libnsl.so.1 libnsl libnsl2 libnsl2.i686 libselinux-python

# echo "Load NVMe kernel module"
# sudo modprobe nvme
# echo "Ensure the NVMe module is loaded at boot"
# echo "nvme" | sudo tee -a /etc/modules-load.d/nvme.conf
# echo "Install the tuned package for performance tuning"
# sudo yum install -y tuned
# echo "Enable the virtual-guest profile for optimal performance on virtual machines"
# sudo tuned-adm profile virtual-guest
# echo "Enable and start the tuned service"
# sudo systemctl enable tuned
# sudo systemctl start tuned
# sudo reboot
``