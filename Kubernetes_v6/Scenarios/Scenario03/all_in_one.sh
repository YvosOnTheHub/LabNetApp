#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario03

echo "#######################################################################################################"
echo "Create ConfigMap for Dashboards"
echo "#######################################################################################################"

kubectl create configmap -n monitoring cm-trident-dashboard --from-file=2_Grafana/Dashboards/
kubectl label configmap -n monitoring cm-trident-dashboard grafana_dashboard=1

echo "#######################################################################################################"
echo "Install Harvest"
echo "#######################################################################################################"

wget -q https://github.com/NetApp/harvest/releases/download/v24.05.2/harvest-24.05.2-1_linux_amd64.tar.gz -O ~/harvest-24.05.2-1_linux_amd64.tar.gz
tar -xf ~/harvest-24.05.2-1_linux_amd64.tar.gz
mv ~/harvest*amd64 ~/harvest
mv ~/harvest/harvest.yml ~/harvest/harvest.bak
mv harvest.yml ~/harvest/
cd ~/harvest
bin/harvest start

echo "#######################################################################################################"
echo "Connect Harvest with Prometheus"
echo "#######################################################################################################"

cd ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario03
kubectl create -f 3_Harvest/Harvest_in_Kubernetes.yaml