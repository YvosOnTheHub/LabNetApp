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
echo "Download Trident 22.01"
echo "#######################################################################################################"

cd
mkdir 22.01.1
cd 22.01.1
wget https://github.com/NetApp/trident/releases/download/v22.01.1/trident-installer-22.01.1.tar.gz
tar -xf trident-installer-22.01.1.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Remove current Trident Operator (21.10.0)"
echo "#######################################################################################################"

kubectl delete -f ~/21.10.0/trident-installer/deploy/bundle.yaml

echo "#######################################################################################################"
echo "Customize the orchestator to reflect the use of a private repository"
echo "#######################################################################################################"

kubectl -n netapp patch torc/trident --type=json -p='[ 
    {"op":"add", "path":"/spec/tridentImage", "value":"registry.demo.netapp.com/trident:22.01.1"}, 
    {"op":"add", "path":"/spec/autosupportImage", "value":"registry.demo.netapp.com/trident-autosupport:22.01"}
]'

echo "#######################################################################################################"
echo "Install new Trident Operator (22.01.1)"
echo "#######################################################################################################"

sed -i s,netapp\/,registry.demo.netapp.com\/, bundle.yaml
kubectl create -f ~/22.01.1/trident-installer/deploy/bundle.yaml

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

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
tridentctl -n trident delete backend --all