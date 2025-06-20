#!/bin/sh
echo "Start python 3.8 installation"
sudo yum install -y gcc openssl-devel libffi-devel bzip2-devel wget
cd /opt
sudo wget https://www.python.org/ftp/python/3.8.9/Python-3.8.9.tgz
sudo tar xzvf Python-3.8.9.tgz
cd Python-3.8.9/
sudo ./configure --enable-optimizations
sudo make altinstall
python3.8 --version
``