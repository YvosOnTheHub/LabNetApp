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
echo "Download Trident 21.07"
echo "#######################################################################################################"

cd
mkdir 21.07.1
cd 21.07.1
wget https://github.com/NetApp/trident/releases/download/v21.07.1/trident-installer-21.07.1.tar.gz
tar -xf trident-installer-21.07.1.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Create the Trident orchestrator CRD"
echo "#######################################################################################################"

kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentorchestrators_crd_post1.16.yaml

echo "#######################################################################################################"
echo "Remove current Trident Operator (20.07.1)"
echo "#######################################################################################################"

kubectl delete -f ~/20.07.1/trident-installer/deploy/bundle.yaml

echo "#######################################################################################################"
echo "Install new Trident Operator (21.07.1)"
echo "#######################################################################################################"

kubectl create -f trident-installer/deploy/bundle.yaml
sleep 30

echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

while [ $(kubectl get -n trident pod | grep Running | wc -l) -ne 5 ]
do
  echo "sleep a bit ..."
  sleep 10
done

tridentctl -n trident version

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
tridentctl -n trident delete backend --all