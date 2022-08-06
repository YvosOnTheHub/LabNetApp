#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password


cd ~/LabNetApp/Kubernetes_v5/Addendum/Addenda05
echo "##############################################"
echo "# METALLB IMAGES MANAGEMENT"
echo "##############################################"

if [[ $# -eq 2 ]];then
  sh addenda05_pull_images.sh $1 $2
else
  sh addenda05_pull_images.sh
fi

echo "#######################################################################################################"
echo "Retrieve MetalLB 0.9.6 manifests & update image location"
echo "#######################################################################################################"

wget https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
wget https://raw.githubusercontent.com/google/metallb/v0.9.6/manifests/metallb.yaml

sed -i s,metallb\/,registry.demo.netapp.com\/metallb\/, metallb.yaml

echo "#######################################################################################################"
echo "Install MetalLB 0.9.6"
echo "#######################################################################################################"

kubectl apply -f namespace.yaml
kubectl apply -f metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

echo "#######################################################################################################"
echo "Configure MetalLB"
echo "#######################################################################################################"

kubectl apply -f metallb-configmap.yml
