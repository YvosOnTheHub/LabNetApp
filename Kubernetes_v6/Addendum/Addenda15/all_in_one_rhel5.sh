echo
echo "#######################################################################################################"
echo "Install KubeVirt"
echo "#######################################################################################################"

kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/v1.6.2/kubevirt-operator.yaml
echo
frames="/ | \\ -"
while [ $(kubectl get -n kubevirt deploy | grep -e '2/2' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the KubeVirt Operator to be ready $frame" 
    done
done
echo

kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/v1.6.2/kubevirt-cr.yaml
echo
while [ $(kubectl get -n kubevirt deploy | grep -e '2/2' | wc -l) -ne 3 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the KubeVirt instance to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "Enable Nested Virtualization on the nodes"
echo "#######################################################################################################"
kubectl -n kubevirt patch kubevirt kubevirt --type=merge --patch '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":true}}}}'

echo
echo "#######################################################################################################"
echo "Enable HotplugVolumes and DeclarativeHotplugVolumes"
echo "#######################################################################################################"
kubectl -n kubevirt patch kubevirt kubevirt --type=merge \
  -p '{"spec":{"configuration":{"developerConfiguration":{"featureGates":["HotplugVolumes","DeclarativeHotplugVolumes"]}}}}'

echo
echo "#######################################################################################################"
echo "Install virtctl"
echo "#######################################################################################################"
mkdir -p ~/kubevirt && cd ~/kubevirt
wget https://github.com/kubevirt/kubevirt/releases/download/v1.6.2/virtctl-v1.6.2-linux-amd64
chmod +x virtctl-v1.6.2-linux-amd64
mv virtctl-v1.6.2-linux-amd64 /usr/local/bin/virtctl

echo
echo "#######################################################################################################"
echo "Install Kubevirt Dashboard"
echo "#######################################################################################################"
wget https://raw.githubusercontent.com/kubevirt-manager/kubevirt-manager/refs/tags/v1.5.4/kubernetes/bundled.yaml -O kubevirt-manager.yaml
sed -i '/^[[:space:]]*image:/ s/nightly/1.5.4/' kubevirt-manager.yaml
sed -i '/^[[:space:]]*image:/ s/kubevirtmanager/quay.io\/yvosonthehub\/kubevirtmanager/' kubevirt-manager.yaml
sed -i '/^[[:space:]]*containers:/i\      nodeSelector:\n          kubernetes.io\/os: linux' kubevirt-manager.yaml
sed -i 's/ClusterIP/NodePort/' kubevirt-manager.yaml
kubectl create -f kubevirt-manager.yaml

echo
while [ $(kubectl get -n kubevirt-manager po | grep -e '1/1' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the KubeVirt Dashboard to be ready $frame" 
    done
done               

KVMGR=$(kubectl -n kubevirt-manager get svc kubevirt-manager -o jsonpath="{.spec.ports[0].nodePort}")

echo
echo "#######################################################################################################"
echo "The KubeVirt dashboard NodePort is $KVMGR"
echo "#######################################################################################################"