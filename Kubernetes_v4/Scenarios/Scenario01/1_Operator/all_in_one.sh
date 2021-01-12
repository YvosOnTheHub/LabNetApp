#!/bin/bash

# OPTIONAL PARAMETERS:
# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

if [ $# -eq 2 ]
  then
    sh scenario01_pull_images.sh $1 $2
fi

if [ $(kubectl get nodes -o=jsonpath='{range .items[*]}[{.metadata.name}, {.metadata.labels}]{"\n"}{end}' | grep "topology.kubernetes.io" | wc -l) = 0 ]
  then
    echo "#######################################################################################################"
    echo "Add Region & Zone labels to Kubernetes nodes"
    echo "#######################################################################################################"

    kubectl label node rhel1 "topology.kubernetes.io/region=trident"
    kubectl label node rhel2 "topology.kubernetes.io/region=trident"
    kubectl label node rhel3 "topology.kubernetes.io/region=trident"

    kubectl label node rhel1 "topology.kubernetes.io/zone=west"
    kubectl label node rhel2 "topology.kubernetes.io/zone=east"
    kubectl label node rhel3 "topology.kubernetes.io/zone=admin"

    if [ $(kubectl get nodes | wc -l) = 5 ]
    then
      kubectl label node rhel4 "topology.kubernetes.io/region=trident"
      kubectl label node rhel4 "topology.kubernetes.io/zone=north"
    fi      
fi

echo "#######################################################################################################"
echo "Download Trident 20.10.0"
echo "#######################################################################################################"

cd
mv trident-installer/ trident-installer_19.07
wget https://github.com/NetApp/trident/releases/download/v20.10.0/trident-installer-20.10.0.tar.gz
tar -xf trident-installer-20.10.0.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Remove current Trident Operator"
echo "#######################################################################################################"

kubectl delete -f trident-installer/deploy/bundle.yaml

echo "#######################################################################################################"
echo "Install new Trident Operator"
echo "#######################################################################################################"

kubectl create -f trident-installer/deploy/bundle.yaml

sleep 30s
echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

tridentctl -n trident version

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
tridentctl -n trident delete backend --all