#!/bin/bash

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario02

echo "#######################################################################################################"
echo "Creating NAS Backend with kubectl"
echo "#######################################################################################################"

kubectl create -n trident -f secret_ontap_nfs-svm_username.yaml
kubectl create -n trident -f backend_nas-default.yaml
kubectl create -n trident -f backend_nas-eco-default.yaml

echo "#######################################################################################################"
echo "Creating NAS Storage Class"
echo "#######################################################################################################"

kubectl create -f sc-csi-ontap-nas.yaml
kubectl create -f sc-csi-ontap-nas-eco.yaml
