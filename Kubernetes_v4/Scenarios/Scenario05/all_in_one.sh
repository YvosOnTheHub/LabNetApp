#!/bin/bash

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario05

echo "#######################################################################################################"
echo "Creating SAN Backends with kubectl"
echo "#######################################################################################################"

kubectl create -n trident -f secret_ontap_iscsi-svm_username.yaml
kubectl create -n trident -f backend_san-secured.yaml
kubectl create -n trident -f backend_san-eco.yaml

echo "#######################################################################################################"
echo "Creating SAN Storage Class"
echo "#######################################################################################################"

kubectl create -f sc-csi-ontap-san.yaml
kubectl create -f sc-csi-ontap-san-eco.yaml
