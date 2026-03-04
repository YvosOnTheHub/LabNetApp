#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario02

echo "#######################################################################################################"
echo "Create File (NFS & SMB) backends"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/secret-ontap-nas-svm-creds.yaml
kubectl create -f 1_Local_User/backend-nfs-ontap-nas.yaml
kubectl create -f 1_Local_User/backend-nfs-ontap-nas-eco.yaml
kubectl create -f 1_Local_User/backend-smb-ontap-nas.yaml

echo "#######################################################################################################"
echo "Create storage classes"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/sc-nfs-ontap-nas.yaml
kubectl create -f 1_Local_User/sc-nfs-ontap-nas-eco.yaml
kubectl create -f 1_Local_User/sc-smb-ontap-nas.yaml