#!/bin/bash

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
if [[ $(kubectl get tridentbackendconfigs -n trident | wc -l) -ne 0 ]]; then
  kubectl get -n trident tbc -o name | xargs kubectl delete -n trident
  sleep 2 
fi

if [[ $(tridentctl -n trident get backend | wc -l) -ne 4 ]]; then
  tridentctl -n trident delete backend --all
fi

echo
echo "#######################################################################################################"
echo "Uninstall Trident & associated CRD"
echo "#######################################################################################################"

kubectl patch torc trident -n trident --type=merge -p '{"spec":{"wipeout":["crds"],"uninstall":true}}'

echo
echo "#######################################################################################################"
echo "Uninstall Trident's provisioner & remaining objects"
echo "#######################################################################################################"

while [ $(kubectl get crd | grep trident | wc -l) -ne 1 ]
do
  echo "sleep a bit ..."
  sleep 10
done

kubectl delete crd tridentorchestrators.trident.netapp.io

kubectl delete -n trident deploy trident-operator
kubectl delete PodSecurityPolicy tridentoperatorpods
kubectl delete ClusterRole trident-operator
kubectl delete ClusterRoleBinding trident-operator
kubectl delete namespace trident