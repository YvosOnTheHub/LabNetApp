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
echo "Install Containerized Data Importer (CDI)"
echo "#######################################################################################################"
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.63.1/cdi-operator.yaml
echo
while [ $(kubectl get -n cdi po | grep -e '1/1' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the CDI Operator to be ready $frame" 
    done
done

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
kubectl -n cdi patch cdi cdi --type merge -p "{\"spec\":{\"config\":{\"uploadProxyURLOverride\":\"https://$CDILBDIP:443\"}}}"

echo
echo "#######################################################################################################"
echo "the CDI Proxy IP is $CDILBDIP"
echo "#######################################################################################################"