# Default lab is Kubernetes 1.29 → KubeVirt 1.6.6
# Kubernetes 1.32 → KubeVirt 1.7.4
# Kubernetes 1.36 → KubeVirt 1.9.0
K8S_MINOR=$(kubectl get --raw /version 2>/dev/null | sed -n 's/.*"minor"[ ]*:[ ]*"\([0-9]*\).*/\1/p')
if [ "${K8S_MINOR:-0}" -ge 36 ]; then
  KUBEVIRT_VERSION="1.9.0"
elif [ "${K8S_MINOR:-0}" -ge 32 ]; then
  KUBEVIRT_VERSION="1.7.4"
else
  KUBEVIRT_VERSION="1.6.6"
fi

echo
echo "#######################################################################################################"
echo "Install KubeVirt v${KUBEVIRT_VERSION} (Kubernetes 1.${K8S_MINOR})"
echo "#######################################################################################################"

kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/kubevirt-operator.yaml
echo
frames="/ | \\ -"
# Deployments not fully ready in a namespace (returns 1 when the namespace has none yet)
# The KubeVirt component list & their replica counts vary between releases, so never hardcode them
not_ready_deploy() {
    kubectl get deploy -n "$1" --no-headers 2>/dev/null | \
        awk '{split($2,r,"/"); if (r[1]=="0" || r[1]!=r[2]) n++} END {if (NR==0) print 1; else print n+0}'
}

while [ "$(not_ready_deploy kubevirt)" -ne 0 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the KubeVirt Operator to be ready $frame" 
    done
done
echo

kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/kubevirt-cr.yaml
echo
while [ "$(kubectl -n kubevirt get kubevirt kubevirt -o jsonpath='{.status.phase}' 2>/dev/null)" != "Deployed" ] || \
      [ "$(not_ready_deploy kubevirt)" -ne 0 ]; do
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
wget https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/virtctl-v${KUBEVIRT_VERSION}-linux-amd64
chmod +x virtctl-v${KUBEVIRT_VERSION}-linux-amd64
mv virtctl-v${KUBEVIRT_VERSION}-linux-amd64 /usr/local/bin/virtctl

echo
echo "#######################################################################################################"
echo "Install & Customize Containerized Data Importer (CDI)"
echo "#######################################################################################################"
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.63.1/cdi-operator.yaml
echo
while [ $(kubectl get -n cdi po | grep -e '1/1' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the CDI Operator to be ready $frame" 
    done
done
echo
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.63.1/cdi-cr.yaml
echo
while [ $(kubectl get -n cdi po | grep -e '1/1' | wc -l) -ne 4 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the CDI Instance to be ready $frame" 
    done
done

kubectl patch cdi cdi --type=merge -p '{"spec":{"config":{"insecureRegistries":["registry.demo.netapp.com"]}}}'


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