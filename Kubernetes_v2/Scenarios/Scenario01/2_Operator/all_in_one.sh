#!/bin/bash

echo "#######################################################################################################"
echo "Check & Install JQ if necessary"
echo "#######################################################################################################"

if [ $(yum info jq | grep Repo | awk '{ print $3 }') != "installed" ]
  then yum install -y jq
fi

echo "#######################################################################################################"
echo "Uninstall Trident 19.07.1"
echo "#######################################################################################################"

tridentctl -n trident uninstall

echo "#######################################################################################################"
echo "Download Trident 20.07.1"
echo "#######################################################################################################"

cd
mv trident-installer/ trident-installer_19.07
wget https://github.com/NetApp/trident/releases/download/v20.07.1/trident-installer-20.07.1.tar.gz
tar -xf trident-installer-20.07.1.tar.gz

echo "#######################################################################################################"
echo "Remove CSI Snapshots Alpha CRD"
echo "#######################################################################################################"

tridentctl -n trident obliviate alpha-snapshot-crd

echo "#######################################################################################################"
echo "Install Trident CR"
echo "#######################################################################################################"

if [ $(kubectl version -o=json | jq -r ".clientVersion.minor") = "15" ]
then
  kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentprovisioners_crd_pre1.16.yaml
else
  kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentprovisioners_crd_post1.16.yaml
fi

echo "#######################################################################################################"
echo "Install Trident Operator"
echo "#######################################################################################################"

kubectl create -f trident-installer/deploy/bundle.yaml

echo "#######################################################################################################"
echo "Install Trident Provisioner"
echo "#######################################################################################################"

kubectl create -f trident-installer/deploy/crds/tridentprovisioner_cr.yaml
sleep 30s

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
tridentctl -n trident delete backend --all

echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

tridentctl -n trident version