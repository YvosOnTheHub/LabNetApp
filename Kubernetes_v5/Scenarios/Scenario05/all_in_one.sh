#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario05

echo "#######################################################################################################"
echo "Creating SAN Backends with kubectl"
echo "#######################################################################################################"

kubectl create -n trident -f secret-ontap-iscsi-svm-chap.yaml
kubectl create -n trident -f backend-san-secured.yaml
kubectl create -n trident -f backend-san-eco.yaml

echo "#######################################################################################################"
echo "Creating SAN Storage Class"
echo "#######################################################################################################"

kubectl create -f sc-csi-ontap-san.yaml
kubectl create -f sc-csi-ontap-san-eco.yaml
