#!/bin/bash

ssh -o "StrictHostKeyChecking no" root@rhel6 wget https://github.com/NetApp/harvest/releases/download/v21.05.2/harvest-21.05.2-1.x86_64.rpm
ssh -o "StrictHostKeyChecking no" root@rhel6 wget https://raw.githubusercontent.com/YvosOnTheHub/LabNetApp/master/Kubernetes_v4/Scenarios/Scenario03/4_Harvest/harvest.yml
ssh -o "StrictHostKeyChecking no" root@rhel6 yum install -y harvest-21.05.2-1.x86_64.rpm
ssh -o "StrictHostKeyChecking no" root@rhel6 rm -f /opt/harvest/harvest.yml
ssh -o "StrictHostKeyChecking no" root@rhel6 mv harvest.yml /opt/harvest/
ssh -o "StrictHostKeyChecking no" root@rhel6 "cd /opt/harvest && bin/harvest start"

echo "### Integrating Harvest with Kubernetes & Prometheus"
cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario03/4_Harvest
kubectl create -f Harvest_in_Kubernetes.yaml