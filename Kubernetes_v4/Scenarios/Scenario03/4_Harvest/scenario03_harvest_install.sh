#!/bin/bash

ssh -o "StrictHostKeyChecking no" root@rhel6 wget https://github.com/NetApp/harvest/releases/download/v21.08.0/harvest-21.08.0-6.x86_64.rpm
sleep 15
ssh -o "StrictHostKeyChecking no" root@rhel6 wget https://raw.githubusercontent.com/YvosOnTheHub/LabNetApp/master/Kubernetes_v4/Scenarios/Scenario03/4_Harvest/harvest.yml
ssh -o "StrictHostKeyChecking no" root@rhel6 yum install -y harvest-21.08.0-6.x86_64.rpm
ssh -o "StrictHostKeyChecking no" root@rhel6 rm -f /opt/harvest/harvest.yml
ssh -o "StrictHostKeyChecking no" root@rhel6 mv harvest.yml /opt/harvest/
ssh -o "StrictHostKeyChecking no" root@rhel6 "cd /opt/harvest && bin/harvest start"

HARVESTSTATUS=$(ssh -o "StrictHostKeyChecking no" root@rhel6 "cd /opt/harvest && bin/harvest status" | grep lod | awk '{print $3}')
if [[ $HARVESTSTATUS -eq "not" ]];then
  ssh -o "StrictHostKeyChecking no" root@rhel6 "cd /opt/harvest && bin/harvest start"
fi

echo "### Integrating Harvest with Kubernetes & Prometheus"
cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario03/4_Harvest

PROMVERSION=$(helm list -n monitoring | tail -1 | awk '{print $1}')
if [[ $PROMVERSION == "prometheus-operator" ]];then
  sed -i s'/prom-operator/prometheus-operator/' Harvest_in_Kubernetes.yaml
fi

kubectl create -f Harvest_in_Kubernetes.yaml