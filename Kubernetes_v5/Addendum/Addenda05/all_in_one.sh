#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Addendum/Addenda05

echo "#######################################################################################################"
echo "Install MetalLB 0.13.10"
echo "#######################################################################################################"

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace -f metallb-values.yaml

frames="/ | \\ -"
while [ $(kubectl get -n metallb-system deploy | grep metal | awk '{print $4}') -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for MetalLB to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "Configure MetalLB"
echo "#######################################################################################################"

kubectl apply -f metallb-ipaddresspool.yaml
kubectl apply -f metallb-l2advert.yaml
