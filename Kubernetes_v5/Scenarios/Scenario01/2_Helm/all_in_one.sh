#!/bin/bash

# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep trident | grep 22.01.1 | wc -l) -eq 0 ]]; then
  if [ $# -eq 0 ]; then
      echo "No arguments supplied"
      echo "Please add the following parameters to the shell script:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
  else 
       sh ../scenario01_pull_images.sh $1 $2
  fi
fi

echo "#######################################################################################################"
echo "Add Region & Zone labels to Kubernetes nodes"
echo "#######################################################################################################"

kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite

kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite

if [ $(kubectl get nodes | wc -l) = 5 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=east"
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1"
fi      

echo "#######################################################################################################"
echo "Uninstall the current Trident installation"
echo "#######################################################################################################"

sh trident_uninstall.sh

echo "#######################################################################################################"
echo "Download Trident 22.01.1"
echo "#######################################################################################################"

cd
mkdir 22.01.1
cd 22.01.1
wget https://github.com/NetApp/trident/releases/download/v22.01.1/trident-installer-22.01.1.tar.gz
tar -xf trident-installer-22.01.1.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Install new Trident Operator (22.01.1) with Helm"
echo "#######################################################################################################"

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart  
helm repo update
helm install trident netapp-trident/trident-operator --version 22.1.1 -n trident --create-namespace --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:22.01,operatorImage=registry.demo.netapp.com/trident-operator:22.01.1,tridentImage=registry.demo.netapp.com/trident:22.01.1

echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

tridentctl -n trident version

