if [[ $# -ne 2 ]];then
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: S3 Bucket Access key"
      echo " - Parameter2: S3 Bucket Secret"
      exit 0
fi

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
sleep 5

wget https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/custom-resources.yaml
sed -i '/^\s*cidr/s/: .*$/: 192.168.20.0\/21/' custom-resources.yaml
sed -i '/^\s*encapsulation/s/: .*$/: VXLAN/' custom-resources.yaml
kubectl create -f ./custom-resources.yaml

frames="/ | \\ -"
while [ $(kubectl get nodes | grep NotReady | wc -l) -eq 1 ]
do
    for frame in $frames; do
        sleep 0.5; printf "\rsleeping a bit - waiting for the control node to be ready $frame" 
    done
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

frames="/ | \\ -"
while [ $(kubectl get nodes | grep NotReady | wc -l) -eq 1 ]
do
    for frame in $frames; do
        sleep 0.5; printf "\rsleeping a bit - waiting for all nodes to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "# Install Helm"
echo "#######################################################################################################"
echo
cd
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

cd
mkdir 25.06.0 && cd 25.06.0
wget https://github.com/NetApp/trident/releases/download/v25.06.0/trident-installer-25.06.0.tar.gz
tar -xf trident-installer-25.06.0.tar.gz
ln -sf /root/25.06.0/trident-installer/tridentctl /usr/local/bin/tridentctl

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 100.2506.0 -n trident --create-namespace \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:25.06.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:25.06.0 \
--set tridentImage=registry.demo.netapp.com/trident:25.06.0 \
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

cd
echo "############################################"
echo "### Snap Class & snapshot controller"
echo "############################################"

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

cat << EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snap-class
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: csi.trident.netapp.io
deletionPolicy: Delete
EOF

echo "############################################"
echo "### Trident configuration"
echo "############################################"

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: svm-credentials
  namespace: trident
type: Opaque
stringData:
  username: trident
  password: Netapp1!
---
apiVersion: trident.netapp.io/v1
kind: TridentBackendConfig
metadata:
  name: backend-nfs
  namespace: trident
spec:
  version: 1
  backendName: nfs
  storageDriverName: ontap-nas
  managementLIF: 192.168.0.140
  autoExportCIDRs:
  - 192.168.0.0/24
  autoExportPolicy: true
  credentials:
    name: svm-credentials
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc-nfs
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  storagePools: "nfs:aggr2"
allowVolumeExpansion: true
EOF

echo "############################################"
echo "### Trident Protect install"
echo "############################################"
cd

cat <<EOF >> protectValues.yaml
image:
  registry: registry.demo.netapp.com
imagePullSecrets:
- name: regcred
controller:
  image:
    registry: registry.demo.netapp.com
rbacProxy:
  image:
    registry: registry.demo.netapp.com
crCleanup:
  imagePullSecrets:
  - name: regcred
webhooksCleanup:
  imagePullSecrets:
  - name: regcred
EOF

kubectl create ns trident-protect
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/
helm registry login registry.demo.netapp.com -u registryuser -p Netapp1!
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com

helm install trident-protect netapp-trident-protect/trident-protect \
  --set clusterName=lod2 \
  --version 100.2506.0 \
  --namespace trident-protect -f protectValues.yaml

curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/25.06.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin

curl -L -O https://github.com/NetApp/tridentctl-protect/releases/download/25.06.0/tridentctl-completion.bash
mkdir -p ~/.bash/completions
mv tridentctl-completion.bash ~/.bash/completions/
source ~/.bash/completions/tridentctl-completion.bash

cat <<EOT >> ~/.bashrc
source ~/.bash/completions/tridentctl-completion.bash
EOT

kubectl create secret generic -n trident-protect s3-creds --from-literal=accessKeyID=$1 --from-literal=secretAccessKey=$2

frames="/ | \\ -"
while [ $(kubectl get -n trident-protect pod | grep Running | grep -e '2/2' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident Protect to be ready $frame" 
    done
done
echo

tridentctl protect create appvault OntapS3 ontap-s3-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect

cp ~/.bashrc ~/.bashrc.bak
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
source ~/.bashrc
