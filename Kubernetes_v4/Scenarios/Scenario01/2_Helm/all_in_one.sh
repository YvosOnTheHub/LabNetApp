#!/bin/bash

# OPTIONAL PARAMETERS:
# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

if [ $# -eq 2 ]
  then
    sh ../scenario01_pull_images.sh $1 $2
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
echo "Uninstall the current Trident installation"
echo "#######################################################################################################"

sh trident_uninstall.sh

echo "#######################################################################################################"
echo "Download Trident 21.07.2"
echo "#######################################################################################################"

cd
mkdir 21.07.2
cd 21.07.2
wget https://github.com/NetApp/trident/releases/download/v21.07.2/trident-installer-21.07.2.tar.gz
tar -xf trident-installer-21.07.2.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Install new Trident Operator (21.07.2) with Helm"
echo "#######################################################################################################"

kubectl create namespace trident
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 21.7.2 -n trident
# DEPRECATED:
# helm install trident trident-installer/helm/trident-operator-21.07.2.tgz -n trident

sleep 30s
echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

tridentctl -n trident version

