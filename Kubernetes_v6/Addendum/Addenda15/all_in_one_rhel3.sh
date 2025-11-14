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
echo "Enable Feature Gates"
echo "#######################################################################################################"
# https://github.com/kubevirt/kubevirt/blob/main/pkg/virt-config/featuregate/active.go
kubectl -n kubevirt patch kubevirt kubevirt --type=merge \
  -p '{"spec":{"configuration":{"developerConfiguration":{"featureGates":["ExpandDisks","HotplugVolumes","DeclarativeHotplugVolumes","Snapshot"]}}}}'

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
echo "Install Containerized Data Importer (CDI)"
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


echo
echo "#######################################################################################################"
echo "Configure CDI Upload proxy"
echo "#######################################################################################################"
cat << EOF | kubectl apply  -f -
apiVersion: v1
kind: Service
metadata:
  name: cdi-uploadproxy-lb
  namespace: cdi
spec:
  selector:
    cdi.kubevirt.io: cdi-uploadproxy
  ports:
    - port: 443
      targetPort: 8443
      protocol: TCP
  type: LoadBalancer
EOF

CDILBDIP=$(kubectl -n cdi get svc cdi-uploadproxy-lb -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
kubectl patch cdi cdi --type merge -p "{\"spec\":{\"config\":{\"uploadProxyURLOverride\":\"https://$CDILBDIP:443\"}}}"

kubectl patch cdi cdi --type merge -p '{"spec": {"config": {"insecureRegistries": ["registry.demo.netapp.com"]}}}'

echo
echo "#######################################################################################################"
echo "Install Kubevirt Dashboard"
echo "#######################################################################################################"
wget https://raw.githubusercontent.com/kubevirt-manager/kubevirt-manager/refs/tags/v1.5.3/kubernetes/bundled.yaml -O kubevirt-manager.yaml
sed -i '/^[[:space:]]*image:/ s/$/-nginx-1-29-2/' kubevirt-manager.yaml
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
echo "Install ORAS"
echo "#######################################################################################################"
cd
wget https://github.com/oras-project/oras/releases/download/v1.3.0/oras_1.3.0_linux_amd64.tar.gz -O /tmp/oras.tar.gz
tar -C /tmp/ -xzf /tmp/oras.tar.gz
mv /tmp/oras /usr/local/bin/oras
chmod +x /usr/local/bin/oras
rm -rf /tmp/oras

echo
echo "#######################################################################################################"
echo "The CDI Proxy IP is $CDILBDIP"
echo "The KubeVirt dashboard NodePort is $KVMGR"
echo "#######################################################################################################"