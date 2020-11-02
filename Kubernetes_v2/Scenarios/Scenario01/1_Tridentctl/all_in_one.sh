#!/bin/bash

if [ $(kubectl version -o=json | jq -r ".clientVersion.minor") >= "17" ] 
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
echo "Uninstall Trident 19.07.1"
echo "#######################################################################################################"

tridentctl -n trident uninstall

echo "#######################################################################################################"
echo "Remove CSI Snapshots Alpha CRD"
echo "#######################################################################################################"

tridentctl -n trident obliviate alpha-snapshot-crd

echo "#######################################################################################################"
echo "Install Trident 20.10.0"
echo "#######################################################################################################"

tridentctl -n trident install

echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

kubectl -n trident get tridentversions