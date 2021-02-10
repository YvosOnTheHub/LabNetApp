#!/bin/bash

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
tridentctl -n trident delete backend --all

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

while [ $(kubectl get crd | grep trident | wc -l) -ne 1 ]
do
  echo "sleep a bit ..."
  sleep 10
done

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