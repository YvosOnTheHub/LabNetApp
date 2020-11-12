#!/bin/bash

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario05

echo "#######################################################################################################"
echo "Creating SAN Backend"
echo "#######################################################################################################"

tridentctl -n trident create backend -f backend-san-secured.json
tridentctl -n trident create backend -f backend-san-eco-default.json


echo "#######################################################################################################"
echo "Creating SAN Storage Class"
echo "#######################################################################################################"

kubectl create -f sc-csi-ontap-san.yaml
kubectl create -f sc-csi-ontap-san-eco.yaml
