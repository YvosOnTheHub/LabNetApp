#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Addendum/Addenda05

echo "#######################################################################################################"
echo "Install MetalLB 0.13.10"
echo "#######################################################################################################"

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace -f metallb-values.yaml

echo "#######################################################################################################"
echo "Configure MetalLB"
echo "#######################################################################################################"

kubectl apply -f metallb-ipaddresspool.yaml
kubectl apply -f metallb-l2advert.yaml
