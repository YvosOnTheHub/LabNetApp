#!/bin/bash

echo "#######################################################################################################"
echo "Install PIP"
echo "#######################################################################################################"

# test repo availability 
REPO_URL='http://repomirror-rtp.eng.netapp.com/rhel/9server-x86_64//rhel-9-for-x86_64-appstream-rpms/repodata/repomd.xml'

if curl -sSfI "$REPO_URL" >/dev/null 2>&1; then
  dnf install -y python-pip
else
  wget -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
  python3 /tmp/get-pip.py
fi

echo "#######################################################################################################"
echo "Install Ansible & NetApp Python Library"
echo "#######################################################################################################"

pip install ansible-core==2.15.12 netapp-lib

echo "#######################################################################################################"
echo "Install NetApp ONTAP Collection"
echo "#######################################################################################################"

ansible-galaxy collection install netapp.ontap --ignore-certs




