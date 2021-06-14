#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL ArgoCD"
echo "#"
echo "#######################################################################################################"
echo

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.0.2/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 10

ARGOCDIP=$(kubectl get svc -n argocd argocd-server --no-headers | awk '{ print $4 }')
echo
echo "TO CONNECT TO ArgoCD, USE THE FOLLOWING ADDRESS: $ARGOCDIP"
echo
sleep 20
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo
echo "TO LOG INTO ArgoCD WITH 'admin', USE THE FOLLOWING PASSWORD: $ARGOCDPWD"
echo