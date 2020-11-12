#!/bin/bash

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario02

echo "#######################################################################################################"
echo "Creating NAS Backend"
echo "#######################################################################################################"

tridentctl -n trident create backend -f backend-nas-default.json
tridentctl -n trident create backend -f backend-nas-eco-default.json

echo "#######################################################################################################"
echo "Creating NAS Storage Class"
echo "#######################################################################################################"

kubectl create -f sc-csi-ontap-nas.yaml
kubectl create -f sc-csi-ontap-nas-eco.yaml
