#!/bin/bash
cd /root/LabNetApp/Kubernetes_v6/Addendum/Addenda05
echo
echo "#######################################################################################################"
echo "Install Kubernetes Dashboard with Helm"
echo "#######################################################################################################"
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace -n kubernetes-dashboard -f dashboard_values.yaml

echo
echo "#######################################################################################################"
echo "User Management"
echo "#######################################################################################################"
kubectl create -f dashboard_user.yaml

echo
echo "#######################################################################################################"
echo "Token:"
echo "#######################################################################################################"
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d; echo

echo
echo "#######################################################################################################"
echo "Dashboard Node Port:"
echo "#######################################################################################################"
kg -n kubernetes-dashboard svc kubernetes-dashboard-kong-proxy -o jsonpath={".spec.ports[0].nodePort"};echo

echo "#######################################################################################################"
echo "# REMEMBER TO CONNECT WITH HTTPS NOT HTTP"
echo "#######################################################################################################"