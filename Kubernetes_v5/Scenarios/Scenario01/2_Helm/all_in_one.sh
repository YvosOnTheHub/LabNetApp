#!/bin/bash

# OPTIONAL PARAMETERS: 
# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

if [[ $(yum info jq -y 2> /dev/null | grep Repo | awk '{ print $3 }') != "installed" ]]; then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi

if [[  $(docker images | grep registry | grep trident | grep 22.10.0 | wc -l) -eq 0 ]]; then
  if [ $# -eq 2 ]; then
    sh ../scenario01_pull_images.sh $1 $2  
  else
    TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
    RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

    if [[ $RATEREMAINING -lt 20 ]];then
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have many pull requests left ($RATEREMAINING). Consider using your own credentials"
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
    else
      sh ../scenario01_pull_images.sh
    fi
  fi
fi

echo "#######################################################################################################"
echo "Add Region & Zone labels to Kubernetes nodes"
echo "#######################################################################################################"

kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite

kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite

if [ $(kubectl get nodes | wc -l) = 5 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=east"
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1"
fi      

echo "#######################################################################################################"
echo "Uninstall the current Trident installation"
echo "#######################################################################################################"

sh trident_uninstall.sh

echo "#######################################################################################################"
echo "Download Trident 22.10.0"
echo "#######################################################################################################"

cd
mkdir 22.10.0 && cd 22.10.0
wget https://github.com/NetApp/trident/releases/download/v22.10.0/trident-installer-22.10.0.tar.gz
tar -xf trident-installer-22.10.0.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Install new Trident Operator (22.10.0) with Helm"
echo "#######################################################################################################"

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart  
helm repo update
helm install trident netapp-trident/trident-operator --version 22.10.0 -n trident --create-namespace --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:22.10.0,operatorImage=registry.demo.netapp.com/trident-operator:22.10.0,tridentImage=registry.demo.netapp.com/trident:22.10.0

echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
tridentctl -n trident version