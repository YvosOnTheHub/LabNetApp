#!/bin/bash

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
if [[ $(kubectl get -n trident tbc | wc -l) -ne 0 ]]; then
   kubectl get -n trident tbc -o name | xargs kubectl delete -n trident
else
   tridentctl -n trident delete backend --all
fi

echo "#######################################################################################################"
echo "Uninstall Trident & associated CRD"
echo "#######################################################################################################"

if [ $(kubectl get crd | grep tridentprov | wc -l) -eq 1 ]
  then
    kubectl patch tprov trident -n trident --type=merge -p '{"spec":{"wipeout":["crds"],"uninstall":true}}'
  else
    kubectl patch torc trident -n trident --type=merge -p '{"spec":{"wipeout":["crds"],"uninstall":true}}'
fi

echo "#######################################################################################################"
echo "Uninstall Trident's provisioner & remaining objects"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get crd | grep trident | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rSleeping a bit $frame" 
    done
done
echo

if [ $(kubectl get crd | grep tridentprov | wc -l) -eq 1 ]
  then
    kubectl delete crd tridentprovisioners.trident.netapp.io
  else
    kubectl delete crd tridentorchestrators.trident.netapp.io
fi

kubectl delete -n trident deploy trident-operator
kubectl delete PodSecurityPolicy tridentoperatorpods
kubectl delete ClusterRole trident-operator
kubectl delete ClusterRoleBinding trident-operator
kubectl delete namespace trident