#!/bin/bash

value=$(kubectl get tver trident -n trident -o jsonpath='{.trident_version}' 2>/dev/null || true)
if [ "$value" = "24.02.0" ]; then
  echo
  echo "#######################################################################################################"
  echo "Removing Trident 24.02"
  echo "#######################################################################################################"
  sh ../trident_uninstall.sh
fi

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

kubectl label node rhel1 "topology.kubernetes.io/region=dc" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=dc" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=dc" --overwrite

kubectl label node rhel1 "topology.kubernetes.io/zone=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east" --overwrite

if [ $(kubectl get nodes | wc -l) = 5 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=dc" 
  kubectl label node rhel4 "topology.kubernetes.io/zone=east" 
fi

echo
echo "#######################################################################################################"
echo "Remove the current Trident installation"
echo "#######################################################################################################"
helm uninstall trident -n trident

echo
echo "#######################################################################################################"
echo "Download Trident 26.06"
echo "#######################################################################################################"

cd
mkdir 24.02.0 && mv trident-installer 24.02.0/
mkdir 26.06.0 && cd 26.06.0
wget https://github.com/NetApp/trident/releases/download/v26.06.0/trident-installer-26.06.0.tar.gz
tar -xf trident-installer-26.06.0.tar.gz
ln -sf /root/26.06.0/trident-installer/tridentctl /usr/local/bin/tridentctl

echo
echo "#######################################################################################################"
echo "Create a secret for the lab registry"
echo "#######################################################################################################"
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com

echo
echo "#######################################################################################################"
echo "Install new Trident Operator (26.06.0)"
echo "#######################################################################################################"

sed -i s,docker.io\/netapp\/,registry.demo.netapp.com\/, ~/26.06.0/trident-installer/deploy/bundle.yaml
kubectl create -f ~/26.06.0/trident-installer/deploy/bundle.yaml

cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentOrchestrator
metadata:
  name: trident
spec:
  debug: true
  namespace: trident
  tridentImage: registry.demo.netapp.com/trident:26.06.0
  autosupportImage: registry.demo.netapp.com/trident-autosupport:26.06.0
  silenceAutosupport: true
  windows: true
  imagePullSecrets:
  - regcred
EOF

echo
echo "#######################################################################################################"
echo "Check (it takes about 3 to 4 minutes for the upgrade to proceed)"
echo "#######################################################################################################"
echo
frames="/ | \\ -"
until kubectl get crd tridentversions.trident.netapp.io >/dev/null 2>&1; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for CRD tridentversions.trident.netapp.io $frame"
    done
done
echo
until [ "$(kubectl get tver trident -n trident -o jsonpath='{.trident_version}' 2>/dev/null)" = "26.06.0" ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame"
    done
done
echo
until [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '3/3' -e '6/6' | wc -l) -eq 7 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "Check if the topology keys are set in Trident"
echo "#######################################################################################################"
echo

check_topology_keys() {
  kubectl get csinode rhel1 -o jsonpath='{.spec.drivers[?(@.name=="csi.trident.netapp.io")].topologyKeys}' 2>/dev/null
}

if [ "$(check_topology_keys)" = "null" ] || [ -z "$(check_topology_keys)" ]; then
  echo "topologyKeys is null for csi.trident.netapp.io on rhel1 — restarting trident-node-linux daemonset..."
  kubectl rollout restart ds/trident-node-linux -n trident

  echo "Waiting for rollout to complete..."
  kubectl rollout status ds/trident-node-linux -n trident --timeout=300s

  echo "Rechecking topologyKeys..."
  TOPO_KEYS=$(check_topology_keys)
  if [ "$TOPO_KEYS" = "null" ] || [ -z "$TOPO_KEYS" ]; then
    echo "ERROR: topologyKeys is still null after rollout restart. Please investigate manually."
    echo "  kubectl get csinode rhel1 -o yaml | grep -C4 topologyKeys"
    exit 1
  else
    echo "topologyKeys is now set: $TOPO_KEYS"
  fi
else
  echo "topologyKeys is already set: $(check_topology_keys)"
fi


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