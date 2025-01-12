#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario01/1_Helm

echo
echo "#######################################################################################################"
echo "Dealing with Trident images"
echo "#######################################################################################################"
sh ../scenario01_pull_images.sh

echo
echo "#######################################################################################################"
echo "Add Region & Zone labels to Kubernetes nodes"
echo "#######################################################################################################"

kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite

kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite

if [ $(kubectl get nodes | wc -l) = 7 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=east" --overwrite
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1" --overwrite
fi      

echo
echo "#######################################################################################################"
echo "Download Trident 24.10.0"
echo "#######################################################################################################"

cd
mkdir 24.02.0 && mv trident-installer 24.02.0/
mkdir 24.10.0 && cd 24.10.0
wget https://github.com/NetApp/trident/releases/download/v24.10.0/trident-installer-24.10.0.tar.gz
tar -xf trident-installer-24.10.0.tar.gz
ln -sf /root/24.10.0/trident-installer/tridentctl /usr/local/bin/tridentctl

echo
echo "#######################################################################################################"
echo "Create a secret for the lab registry"
echo "#######################################################################################################"
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com

echo
echo "#######################################################################################################"
echo "Upgrade the Trident Operator (24.10.0) with Helm"
echo "#######################################################################################################"

helm repo update
helm upgrade trident netapp-trident/trident-operator --version 100.2410.0 -n trident \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:24.10.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:24.10.0 \
--set tridentImage=registry.demo.netapp.com/trident:24.10.0 \
--set tridentSilenceAutosupport=true \
--set windows=true \
--set imagePullSecrets[0]=regcred

echo
echo "#######################################################################################################"
echo "Check (it takes about 3 to 4 minutes for the upgrade to proceed)"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get tver -A | grep trident | awk '{print $3}') != '24.10.0' ];do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '3/3' -e '6/6' | wc -l) -ne 7 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
tridentctl -n trident version