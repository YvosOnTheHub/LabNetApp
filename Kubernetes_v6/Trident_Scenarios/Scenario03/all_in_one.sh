#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario03

echo
echo "#######################################################################################################"
echo "Grafana image management (use local registry for Docker image)"
echo "#######################################################################################################"
sh scenario03_push_images.sh 

echo
echo "#######################################################################################################"
echo "Create ConfigMap for Dashboards"
echo "#######################################################################################################"
kubectl create configmap -n monitoring cm-trident-dashboard --from-file=2_Grafana/Dashboards/
kubectl label configmap -n monitoring cm-trident-dashboard grafana_dashboard=1

echo
echo "#######################################################################################################"
echo "Install Harvest"
echo "#######################################################################################################"
wget -q https://github.com/NetApp/harvest/releases/download/v24.05.2/harvest-24.05.2-1_linux_amd64.tar.gz -O ~/harvest-24.05.2-1_linux_amd64.tar.gz
mkdir -p ~/harvest
tar -xf ~/harvest-24.05.2-1_linux_amd64.tar.gz -C ~/harvest --strip-components=1
mv ~/harvest/harvest.yml ~/harvest/harvest.bak
cp 3_Harvest/harvest.yml ~/harvest/
cd ~/harvest
bin/harvest start

echo
echo "#######################################################################################################"
echo "Connect Harvest with Prometheus"
echo "#######################################################################################################"
cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario03
kubectl create -f 3_Harvest/Harvest_in_Kubernetes.yaml