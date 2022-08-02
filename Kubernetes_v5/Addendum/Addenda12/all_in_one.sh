#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

cd ~/LabNetApp/Kubernetes_v5/Addendum/Addenda12
echo "##############################################"
echo "# ARGOCD IMAGES MANAGEMENT"
echo "##############################################"

sh addenda12_pull_images.sh $1 $2

echo
echo "#######################################################################################################"
echo "# INSTALL ArgoCD"
echo "#######################################################################################################"

wget https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.3/manifests/install.yaml
sed -i s,quay.io,registry.demo.netapp.com, install.yaml
sed -i s,ghcr.io,registry.demo.netapp.com, install.yaml
sed -i s,redis:7,registry.demo.netapp.com\/redis:7, install.yaml

kubectl create namespace argocd
kubectl apply -n argocd -f install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 45

ARGOCDIP=$(kubectl get svc -n argocd argocd-server --no-headers | awk '{ print $4 }')
echo
echo "TO CONNECT TO ArgoCD, USE THE FOLLOWING ADDRESS: $ARGOCDIP"
echo

ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo
echo "TO LOG INTO ArgoCD WITH 'admin', USE THE FOLLOWING PASSWORD: $ARGOCDPWD"
echo