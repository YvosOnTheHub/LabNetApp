#!/bin/bash

ssh -o "StrictHostKeyChecking no" root@rhel6 "wget -q https://github.com/NetApp/harvest/releases/download/v.22.02.0/harvest-22.02.0-4_linux_amd64.tar.gz"
sleep 10
ssh -o "StrictHostKeyChecking no" root@rhel6 tar -xf harvest-22.02.0-4_linux_amd64.tar.gz
ssh -o "StrictHostKeyChecking no" root@rhel6 mv harvest*amd64 harvest
ssh -o "StrictHostKeyChecking no" root@rhel6 rm -f ~/harvest/harvest.yml
ssh -o "StrictHostKeyChecking no" root@rhel6 wget https://raw.githubusercontent.com/YvosOnTheHub/LabNetApp/master/Kubernetes_v5/Scenarios/Scenario03/4_Harvest/harvest.yml
ssh -o "StrictHostKeyChecking no" root@rhel6 mv harvest.yml ~/harvest/
ssh -o "StrictHostKeyChecking no" root@rhel6 "cd ~/harvest && bin/harvest start"

HARVESTSTATUS=$(ssh -o "StrictHostKeyChecking no" root@rhel6 "cd ~/harvest && bin/harvest status" | grep lod | grep not | wc -l)
if [[ $HARVESTSTATUS -eq "1" ]];then
  ssh -o "StrictHostKeyChecking no" root@rhel6 "cd ~/harvest && bin/harvest start"
fi

echo "#######################################################"
echo "# Integrating Harvest with Kubernetes & Prometheus"
echo "#######################################################"
cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario03/4_Harvest
kubectl create -f Harvest_in_Kubernetes.yaml