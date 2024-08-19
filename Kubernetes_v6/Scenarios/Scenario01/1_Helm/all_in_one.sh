#!/bin/bash

# OPTIONAL PARAMETERS: 
# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

if [[  $(podman images | grep registry | grep trident | grep 24.06.1 | wc -l) -eq 0 ]]; then
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

if [ $(kubectl get nodes | wc -l) = 7 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=east"
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1"
fi      

echo "#######################################################################################################"
echo "Download Trident 24.06.1"
echo "#######################################################################################################"

cd
mkdir 24.02.0 && mv trident-installer 24.02.0/
mkdir 24.06.1 && cd 24.06.1
wget https://github.com/NetApp/trident/releases/download/v24.06.1/trident-installer-24.06.1.tar.gz
tar -xf trident-installer-24.06.1.tar.gz
ln -sf /root/24.06.1/trident-installer/tridentctl /usr/local/bin/tridentctl

echo "#######################################################################################################"
echo "Upgrade the Trident Operator (24.06.1) with Helm"
echo "#######################################################################################################"

helm repo update
helm upgrade trident netapp-trident/trident-operator --version 100.2406.1 -n trident \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:24.06.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:24.06.1 \
--set tridentImage=registry.demo.netapp.com/trident:24.06.1 \
--set tridentSilenceAutosupport=true \
--set windows=true

echo "#######################################################################################################"
echo "Check (it takes about 3 to 4 minutes for the upgrade to proceed)"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get tver -A | grep trident | awk '{print $3}') != '24.06.1' ];do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '6/6' | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
tridentctl -n trident version

echo "#######################################################################################################"
echo "#"
echo "#          TRIDENT 24.06.1 LAB ISSUE:"
echo "#"
echo "#" You must run the following command on both Windows nodes for the installation to complete:
echo "#"
echo "#" crictl pull --creds registryuser:Netapp1! registry.demo.netapp.com/trident:24.06.1
echo "#"
echo "#######################################################################################################"