#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario05

echo "#######################################################################################################"
echo "Create Block TBC corresponding to existing Trident backends"
echo "#######################################################################################################"

kubectl create -f secret-ontap-iscsi-svm-creds.yaml
kubectl create -f secret-ontap-nvme-svm-creds.yaml
kubectl create -f backend-tbc-iscsi.yaml
kubectl create -f backend-tbc-nvme.yaml

echo "#######################################################################################################"
echo "Create SAN-ECO backend for iSCSI"
echo "#######################################################################################################"

kubectl create -f backend-san-eco.yaml
kubectl create -f sc-iscsi-ontap-san-eco.yaml

echo "#######################################################################################################"
echo "Change existing Block SC with a StoragePool parameter"
echo "#######################################################################################################"
kubectl delete sc storage-class-iscsi storage-class-nvme
kubectl create -f sc-iscsi.yaml
kubectl create -f sc-nvme.yaml