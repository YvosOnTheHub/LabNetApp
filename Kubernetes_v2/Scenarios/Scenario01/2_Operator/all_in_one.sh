#!/bin/bash

if [ $(yum info jq | grep Repo | awk '{ print $3 }') != "installed" ]
  then 
    echo "#######################################################################################################"
    echo "Check & Install JQ if necessary"
    echo "#######################################################################################################"
    yum install -y jq
fi

if [ $(kubectl version -o=json | jq -r ".clientVersion.minor") -gt 16 ] 
  then 
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
fi

echo "#######################################################################################################"
echo "Download Trident 20.10.0"
echo "#######################################################################################################"

cd
mv trident-installer/ trident-installer_19.07
wget https://github.com/NetApp/trident/releases/download/v20.10.0/trident-installer-20.10.0.tar.gz
tar -xf trident-installer-20.10.0.tar.gz

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