#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario01/1_Helm

echo
echo "#######################################################################################################"
echo "Dealing with Trident images"
echo "#######################################################################################################"
sh ../scenario01_pull_images.sh

echo
echo "#######################################################################################################"
echo "Host RHEL1 NQN update"
echo "#######################################################################################################"
echo
ssh -o "StrictHostKeyChecking no" root@rhel1 -t "sed -i -E 's/(e0e73e5d221)0/\11/' /etc/nvme/hostnqn"
ssh -o "StrictHostKeyChecking no" root@rhel1 -t "sed -i -E 's/(e0e73e5d221)0/\11/' /etc/nvme/hostid"

echo
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
  kubectl label node rhel4 "topology.kubernetes.io/region=east" --overwrite
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1" --overwrite
fi      

echo
echo "#######################################################################################################"
echo "Download Trident 25.10"
echo "#######################################################################################################"

cd
mkdir 24.02.0 && mv trident-installer 24.02.0/
mkdir 25.10.0 && cd 25.10.0
wget https://github.com/NetApp/trident/releases/download/v25.10.0/trident-installer-25.10.0.tar.gz
tar -xf trident-installer-25.10.0.tar.gz
ln -sf /root/25.10.0/trident-installer/tridentctl /usr/local/bin/tridentctl

echo
echo "#######################################################################################################"
echo "Create a secret for the lab registry"
echo "#######################################################################################################"
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com

echo
echo "#######################################################################################################"
echo "Upgrade the Trident Operator (25.10.0) with Helm"
echo "#######################################################################################################"

helm repo update
helm upgrade trident netapp-trident/trident-operator --version 100.2510.0 -n trident \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:25.10.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:25.10.0 \
--set tridentImage=registry.demo.netapp.com/trident:25.10.0 \
--set tridentSilenceAutosupport=true \
--set windows=true \
--set imagePullSecrets[0]=regcred

echo
echo "#######################################################################################################"
echo "Check (it takes about 3 to 4 minutes for the upgrade to proceed)"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get tver -A | grep trident | awk '{print $3}') != '25.10.0' ];do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '3/3' -e '6/6' | wc -l) -ne 7 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "Enable Trident Autocompletion"
echo "#######################################################################################################"
mkdir -p ~/.bash/completions
tridentctl completion bash > ~/.bash/completions/tridentctl-completion.bash
source ~/.bash/completions/tridentctl-completion.bash
echo 'source ~/.bash/completions/tridentctl-completion.bash' >> ~/.bashrc

echo
echo "#######################################################################################################"
echo "Check Trident"
echo "#######################################################################################################"
echo
tridentctl -n trident version