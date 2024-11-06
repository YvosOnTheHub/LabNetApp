if [[ $(dnf list installed | grep sshpass | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# SSHPASS install"
  echo "##############################################################"  
  dnf install -y sshpass
fi

echo
echo "#######################################################################################################"
echo "# Create a K8S cluster on RHEL5"
echo "#######################################################################################################"
echo

kubeadm init --pod-network-cidr=192.168.20.0/21

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
echo 'KUBECONFIG=$HOME/.kube/config' >> $HOME/.bashrc
source ~/.bashrc

echo
echo "#######################################################################################################"
echo "# Copy KUBECONFIG on RHEL3"
echo "#######################################################################################################"
echo
curl -s --insecure --user root:Netapp1! -T /root/.kube/config sftp://rhel3/root/.kube/config_rhel5

echo
echo "#######################################################################################################"
echo "# Allow user apps on the control plane"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel5 node-role.kubernetes.io/control-plane-

echo
echo "#######################################################################################################"
echo "# Calico images management on RHEL5"
echo "#######################################################################################################"
echo
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman pull -q registry.demo.netapp.com/calico/typha:v3.27.3
podman pull -q registry.demo.netapp.com/calico/pod2daemon-flexvol:v3.27.3
podman pull -q registry.demo.netapp.com/calico/cni:v3.27.3
podman pull -q registry.demo.netapp.com/calico/csi:v3.27.3
podman pull -q registry.demo.netapp.com/calico/kube-controllers:v3.27.3
podman pull -q registry.demo.netapp.com/calico/node:v3.27.3
podman pull -q registry.demo.netapp.com/calico/node-driver-registrar:v3.27.3
podman pull -q registry.demo.netapp.com/calico/apiserver:v3.27.3
podman tag registry.demo.netapp.com/calico/typha:v3.27.3 docker.io/calico/typha:v3.27.3
podman tag registry.demo.netapp.com/calico/pod2daemon-flexvol:v3.27.3 docker.io/calico/pod2daemon-flexvol:v3.27.3 
podman tag registry.demo.netapp.com/calico/cni:v3.27.3 docker.io/calico/cni:v3.27.3
podman tag registry.demo.netapp.com/calico/csi:v3.27.3 docker.io/calico/csi:v3.27.3
podman tag registry.demo.netapp.com/calico/kube-controllers:v3.27.3 docker.io/calico/kube-controllers:v3.27.3
podman tag registry.demo.netapp.com/calico/node:v3.27.3 docker.io/calico/node:v3.27.3
podman tag registry.demo.netapp.com/calico/node-driver-registrar:v3.27.3 docker.io/calico/node-driver-registrar:v3.27.3
podman tag registry.demo.netapp.com/calico/apiserver:v3.27.3 docker.io/calico/apiserver:v3.27.3

echo
echo "#######################################################################################################"
echo "# Calico images management on RHEL4"
echo "#######################################################################################################"
echo
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/typha:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/pod2daemon-flexvol:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/cni:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/csi:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/kube-controllers:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/node:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/node-driver-registrar:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman pull -q --creds registryuser:Netapp1! registry.demo.netapp.com/calico/apiserver:v3.27.3

sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/typha:v3.27.3 docker.io/calico/typha:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/pod2daemon-flexvol:v3.27.3 docker.io/calico/pod2daemon-flexvol:v3.27.3 
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/cni:v3.27.3 docker.io/calico/cni:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/csi:v3.27.3 docker.io/calico/csi:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/kube-controllers:v3.27.3 docker.io/calico/kube-controllers:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/node:v3.27.3 docker.io/calico/node:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/node-driver-registrar:v3.27.3 docker.io/calico/node-driver-registrar:v3.27.3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 podman tag registry.demo.netapp.com/calico/apiserver:v3.27.3 docker.io/calico/apiserver:v3.27.3


echo
echo "#######################################################################################################"
echo "# Install & configure Calico"
echo "#######################################################################################################"
echo

mkdir ~/calico && cd ~/calico
wget https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/tigera-operator.yaml
kubectl create -f tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/custom-resources.yaml
sed -i '/^\s*cidr/s/: .*$/: 192.168.20.0\/21/' custom-resources.yaml
sed -i '/^\s*encapsulation/s/: .*$/: VXLAN/' custom-resources.yaml
kubectl create -f ./custom-resources.yaml

while [ $(kubectl get nodes | grep NotReady | wc -l) -eq 1 ]
do
  echo "sleeping a bit - waiting the control node to be ready ..."
  sleep 5
done

kubectl patch installation default --type=merge -p='{"spec": {"calicoNetwork": {"bgp": "Disabled"}}}'

echo
echo "#######################################################################################################"
echo "# Add a second node"
echo "#######################################################################################################"
echo

KUBEADMJOIN=$(kubeadm token create --print-join-command)
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 $KUBEADMJOIN


while [ $(kubectl get nodes | grep NotReady | wc -l) -eq 1 ]
do
  echo "sleeping a bit - waiting for all nodes to be ready ..."
  sleep 5
done

echo
echo "#######################################################################################################"
echo "# Install Helm"
echo "#######################################################################################################"
echo

wget https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz
tar -xvf helm-v3.15.3-linux-amd64.tar.gz
cp -f linux-amd64/helm /usr/local/bin/

echo
echo "#######################################################################################################"
echo "# Install MetalLB"
echo "#######################################################################################################"
echo

mkdir ~/metallb && cd ~/metallb

cat << EOF > metallb-values.yaml
  controller:
    image:
      repository: registry.demo.netapp.com/metallb/controller
      tag: v0.14.5
      
  speaker:
    image:
      repository: registry.demo.netapp.com/metallb/speaker
      tag: v0.14.5
    frr:
      enabled: false
EOF

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace -f metallb-values.yaml

frames="/ | \\ -"
while [ $(kubectl get -n metallb-system pod | grep Running | grep -e '1/1' | wc -l) -ne 3 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for MetalLB to be ready $frame" 
    done
done
echo

cat << EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.220-192.168.0.229
EOF

cat << EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
   - first-pool
EOF

echo
echo "#######################################################################################################"
echo "# Install Trident"
echo "#######################################################################################################"
echo

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 100.2410.0 -n trident --create-namespace \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:24.10.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:24.10.0 \
--set tridentImage=registry.demo.netapp.com/trident:24.10.0 \
--set tridentSilenceAutosupport=true

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '6/6' | wc -l) -ne 4 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "# Secondary Kubernetes cluster ready to be used"
echo "#######################################################################################################"
echo