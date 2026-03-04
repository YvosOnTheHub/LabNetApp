#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario02

echo "#######################################################################################################"
echo "Create File (NFS & SMB) backends"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/secret-ontap-nas-svm-creds.yaml
kubectl create -f 1_Local_User/backend-*.yaml

echo "#######################################################################################################"
echo "Create storage classes"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/sc-*.yaml