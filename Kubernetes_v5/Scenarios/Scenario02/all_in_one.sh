#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario02

echo "#######################################################################################################"
echo "Creating NAS Backend with kubectl"
echo "#######################################################################################################"

kubectl create -n trident -f 1_Local_User/secret-ontap-nfs-svm-username.yaml
kubectl create -n trident -f 1_Local_User/backend-nas-default.yaml
kubectl create -n trident -f 1_Local_User/backend-nas-eco-default.yaml

echo "#######################################################################################################"
echo "Creating NAS Storage Class"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/sc-csi-ontap-nas.yaml
kubectl create -f 1_Local_User/sc-csi-ontap-nas-eco.yaml
