#!/bin/bash

echo "#######################################################################################################"
echo "Install MetalLB 0.9.6"
echo "#######################################################################################################"

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.6/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

echo "#######################################################################################################"
echo "Configure MetalLB"
echo "#######################################################################################################"

cd ~/LabNetApp/Kubernetes_v4/Addendum/Addenda05
kubectl apply -f metallb-configmap.yml
