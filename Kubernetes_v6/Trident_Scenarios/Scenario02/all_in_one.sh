#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario02

echo "#######################################################################################################"
echo "Create NAS TBC corresponding to existing Trident backends"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/secret-ontap-nas-svm-creds.yaml
kubectl create -f 1_Local_User/backend-tbc-nfs.yaml
kubectl create -f 1_Local_User/backend-tbc-smb.yaml

echo "#######################################################################################################"
echo "Create NAS-ECO backend for NFS"
echo "#######################################################################################################"

kubectl create -f 1_Local_User/backend-nas-eco.yaml
kubectl create -f 1_Local_User/sc-nfs-ontap-nas-eco.yaml