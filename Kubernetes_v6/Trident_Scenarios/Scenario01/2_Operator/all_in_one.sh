#!/bin/bash

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

if [ $(kubectl get nodes | wc -l) = 5 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=east" 
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1" 
fi

echo
echo "#######################################################################################################"
echo "Remove the current Trident installation"
echo "#######################################################################################################"
helm uninstall trident -n trident

echo
echo "#######################################################################################################"
echo "Download Trident 25.06.1"
echo "#######################################################################################################"

cd
mkdir 24.02.0 && mv trident-installer 24.02.0/
mkdir 25.06.1 && cd 25.06.1
wget https://github.com/NetApp/trident/releases/download/v25.06.1/trident-installer-25.06.1.tar.gz
tar -xf trident-installer-25.06.1.tar.gz
ln -sf /root/25.06.1/trident-installer/tridentctl /usr/local/bin/tridentctl

echo
echo "#######################################################################################################"
echo "Create a secret for the lab registry"
echo "#######################################################################################################"
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com

echo
echo "#######################################################################################################"
echo "Install new Trident Operator (25.06.1)"
echo "#######################################################################################################"

sed -i s,netapp\/,registry.demo.netapp.com\/, ~/25.06.1/trident-installer/deploy/bundle.yaml
kubectl create -f ~/25.06.1/trident-installer/deploy/bundle.yaml

cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentOrchestrator
metadata:
  name: trident
spec:
  debug: true
  namespace: trident
  tridentImage: registry.demo.netapp.com/trident:25.06.1
  autosupportImage: registry.demo.netapp.com/trident-autosupport:25.06.0
  silenceAutosupport: true
  windows: true
  imagePullSecrets:
  - regcred
EOF

echo
echo "#######################################################################################################"
echo "Check (it takes about 3 to 4 minutes for the upgrade to proceed)"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get tver -A | grep trident | awk '{print $3}') != '25.06.1' ];do
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
tridentctl -n trident version
