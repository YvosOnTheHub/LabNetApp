#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL GITEA on RHEL5"
echo "#"
echo "#######################################################################################################"
echo

cd ~/LabNetApp/Kubernetes_v6/Addendum/Addenda10

if [[ $# -eq 2 ]];then
  sh addenda11_pull_images.sh $1 $2
else
  sh addenda11_pull_images.sh
fi

ssh -o "StrictHostKeyChecking no" root@rhel5 "dnf install -y podman-compose"
ssh -o "StrictHostKeyChecking no" root@rhel5 "git clone --depth 1 --branch master --no-checkout https://github.com/YvosOnTheHub/LabNetApp.git"
ssh -o "StrictHostKeyChecking no" root@rhel5 "cd LabNetApp && git sparse-checkout set Kubernetes_v6/Addendum/Addenda11 && git checkout"
ssh -o "StrictHostKeyChecking no" root@rhel5 "cd Kubernetes_v6/Addendum/Addenda10 && podman-compose up -d"
