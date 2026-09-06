if ! dnf -q list installed sshpass >/dev/null 2>&1; then
  echo "##############################################################"
  echo "# SSHPASS install"
  echo "##############################################################"  

  # test repo availability 
  REPO_URL='http://repomirror-rtp.eng.netapp.com/rhel/9server-x86_64//rhel-9-for-x86_64-appstream-rpms/repodata/repomd.xml'

  if curl --connect-timeout 5 --max-time 10 -sSfI "$REPO_URL" >/dev/null 2>&1; then
    dnf install -y sshpass
  else
    cd /tmp
    curl -LO https://downloads.sourceforge.net/project/sshpass/sshpass/1.09/sshpass-1.09.tar.gz
    tar xzf sshpass-1.09.tar.gz
    cd sshpass-1.09
    ./configure
    make
    make install
  fi
fi

# Optional first argument: Kubernetes version (for example 1.36.4 or v1.36.4).
# With no argument the preinstalled binaries are used (LoD ships 1.29).
CRI_SOCKET="unix:///var/run/crio/crio.sock"
PAUSE_IMAGE="registry.k8s.io/pause:3.10"
TARGET_VERSION="${1:-}"
TARGET_VERSION="${TARGET_VERSION#v}"

if [ -n "$TARGET_VERSION" ]; then
  TARGET_VERSION_V="v${TARGET_VERSION}"
else
  TARGET_VERSION_V=$(kubeadm version -o short 2>/dev/null || true)
  TARGET_VERSION="${TARGET_VERSION_V#v}"
fi
TARGET_MINOR="${TARGET_VERSION%.*}"
K8S_MINOR_NUM="${TARGET_MINOR#1.}"

ensure_k8s_packages_local() {
  if rpm -q kubeadm 2>/dev/null | grep -q "$TARGET_VERSION"; then
    return 0
  fi
  echo "Installing Kubernetes ${TARGET_VERSION} on $(hostname -s)"
  sed -E -i "s#/v1\.[0-9]+/rpm/#/v${TARGET_MINOR}/rpm/#" /etc/yum.repos.d/kubernetes.repo
  yum install -y \
    "kubeadm-${TARGET_VERSION}*" \
    "kubelet-${TARGET_VERSION}*" \
    "kubectl-${TARGET_VERSION}*" \
    --disableexcludes=kubernetes
}

ensure_k8s_packages_remote() {
  local host=$1
  sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" "root@${host}" "bash -s" <<EOF
if rpm -q kubeadm 2>/dev/null | grep -q '${TARGET_VERSION}'; then
  exit 0
fi
echo "Installing Kubernetes ${TARGET_VERSION} on \$(hostname -s)"
sed -E -i 's#/v1\.[0-9]+/rpm/#/v${TARGET_MINOR}/rpm/#' /etc/yum.repos.d/kubernetes.repo
yum install -y \
  'kubeadm-${TARGET_VERSION}*' \
  'kubelet-${TARGET_VERSION}*' \
  'kubectl-${TARGET_VERSION}*' \
  --disableexcludes=kubernetes
EOF
}

ensure_pause_image_local() {
  [ "${K8S_MINOR_NUM:-0}" -ge 31 ] || return 0
  crictl pull "$PAUSE_IMAGE" || true
  mkdir -p /etc/crio/crio.conf.d
  printf '%s\n' '[crio.image]' "pause_image = \"${PAUSE_IMAGE}\"" \
    >/etc/crio/crio.conf.d/99-pause-image.conf
  systemctl daemon-reload
  systemctl restart crio
}

ensure_pause_image_remote() {
  local host=$1
  [ "${K8S_MINOR_NUM:-0}" -ge 31 ] || return 0
  sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" "root@${host}" "bash -s" <<EOF
crictl pull '${PAUSE_IMAGE}' || true
mkdir -p /etc/crio/crio.conf.d
printf '%s\n' '[crio.image]' 'pause_image = "${PAUSE_IMAGE}"' \
  >/etc/crio/crio.conf.d/99-pause-image.conf
systemctl daemon-reload
systemctl restart crio
EOF
}

echo
echo "#######################################################################################################"
echo "# Create a K8S cluster on RHEL5 (${TARGET_VERSION_V})"
echo "#######################################################################################################"
echo

ensure_k8s_packages_local
ensure_k8s_packages_remote rhel4
ensure_pause_image_local
ensure_pause_image_remote rhel4

if [ "${K8S_MINOR_NUM:-0}" -ge 31 ]; then
  cat << EOF > ~/kubeadm-values.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
nodeRegistration:
  criSocket: ${CRI_SOCKET}
  name: rhel5
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
clusterName: kub2
kubernetesVersion: ${TARGET_VERSION_V}
networking:
  podSubnet: "192.168.20.0/21"
EOF
else
  cat << EOF > ~/kubeadm-values.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: "192.168.20.0/21"
clusterName: kub2
EOF
fi

kubeadm init --config ~/kubeadm-values.yaml

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sed -i 's/kubernetes-admin/kub2-admin/' $HOME/.kube/config
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
echo "# KUBECONFIG Management on RHEL3"
echo "#######################################################################################################"
echo
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel3 mv ~/.kube/config ~/.kube/config_rhel3
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel3 "export KUBECONFIG=~/.kube/config_rhel3:~/.kube/config_rhel5 && kubectl config view --merge --flatten > ~/.kube/config && export KUBECONFIG=~/.kube/config"

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
kubectl apply --server-side --force-conflicts -f tigera-operator.yaml

frames="/ | \\ -"
while [ $(kubectl get -n tigera-operator pod | grep Running | grep -e '1/1' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Calico to be ready $frame" 
    done
done
echo

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
if [ "${K8S_MINOR_NUM:-0}" -ge 31 ]; then
  KUBEADMJOIN="${KUBEADMJOIN} --cri-socket ${CRI_SOCKET}"
fi
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
cd
wget https://get.helm.sh/helm-v4.0.5-linux-amd64.tar.gz
tar -xvf helm-v4.0.5-linux-amd64.tar.gz
/bin/cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v4.0.5-linux-amd64.tar.gz

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
helm install metallb metallb/metallb --version 0.14.5 -n metallb-system --create-namespace -f metallb-values.yaml

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
echo "# Configure iSCSI on each node"
echo "#######################################################################################################"
echo

sed -i s/rhel./rhel5/ /etc/iscsi/initiatorname.iscsi
systemctl restart iscsid
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 "sed -i s/rhel./rhel4/ /etc/iscsi/initiatorname.iscsi"
sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel4 systemctl restart iscsid

echo
echo "#######################################################################################################"
echo "# Install Trident"
echo "#######################################################################################################"
echo

cd
mkdir 26.06.1 && cd 26.06.1
wget https://github.com/NetApp/trident/releases/download/v26.06.1/trident-installer-26.06.1.tar.gz
tar -xf trident-installer-26.06.1.tar.gz
ln -sf /root/26.06.1/trident-installer/tridentctl /usr/local/bin/tridentctl

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 100.2606.1 -n trident --create-namespace \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:26.06.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:26.06.1 \
--set tridentImage=registry.demo.netapp.com/trident:26.06.1 \
--set tridentSilenceAutosupport=true

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '6/6' | wc -l) -ne 4 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "############################################"
echo "### Snap Class & snapshot controller"
echo "############################################"

kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd?ref=v8.6.0 | kubectl apply -f -
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/snapshot-controller?ref=v8.6.0 | kubectl apply -f -


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

echo
echo "#######################################################################################################"
echo "# Secondary Kubernetes cluster ready to be used"
echo "#######################################################################################################"
echo

if [[  $(more ~/.bashrc | grep kedit | wc -l) -eq 0 ]];then
  echo
  echo "#######################################################################################################"
  echo "# UPDATE BASHRC"
  echo "#######################################################################################################"
  echo

  cat <<EOT >> ~/.bashrc
source <(kubectl completion bash)
complete -F __start_kubectl k

alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
fi