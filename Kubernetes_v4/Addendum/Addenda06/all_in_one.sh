#!/bin/bash

echo "#######################################################################################################"
echo "Install Kubernetes Dashboard"
echo "#######################################################################################################"

cd /root/LabNetApp/Kubernetes_v4/Addendum/Addenda06
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml
kubectl create -f dashboard-service-account.yaml
kubectl create -f dashboard-clusterrolebinding.yaml

echo "#######################################################################################################"
echo "Patch Dashboard Service"
echo "#######################################################################################################"

kubectl -n kubernetes-dashboard patch service/kubernetes-dashboard -p '{"spec":{"type":"LoadBalancer"}}'

echo "#######################################################################################################"
echo "Dashboard IP address"
echo "#######################################################################################################"
kubectl get svc -n kubernetes-dashboard kubernetes-dashboard