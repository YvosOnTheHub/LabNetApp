#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario05

echo "#######################################################################################################"
echo "Create Block (iSCSI & NVMe) backends"
echo "#######################################################################################################"

kubectl create -f secret-ontap-iscsi-svm-creds.yaml
kubectl create -f secret-ontap-nvme-svm-creds.yaml
kubectl create -f backend-iscsi-ontap-san.yaml
kubectl create -f backend-iscsi-ontap-san-eco.yaml
kubectl create -f backend-iscsi-ontap-san-luks.yaml
kubectl create -f backend-nvme-ontap-san.yaml

echo "#######################################################################################################"
echo "Create Storage classes"
echo "#######################################################################################################"
kubectl create -f sc-iscsi-ontap-san.yaml
kubectl create -f sc-iscsi-ontap-san-eco.yaml
kubectl create -f sc-iscsi-ontap-san-luks.yaml
kubectl create -f sc-nvme-ontap-san.yaml