ping -c1 -W1 -q rhel4 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL4 from the LoD MyLabs page"
  echo "#################################################################"
  exit 0
fi
ping -c1 -W1 -q rhel5 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL5 from the LoD MyLabs page"
  echo "#################################################################"
  exit 0
fi

echo "############################################"
echo "#"
echo "### Windows Nodes: Taint: No Schedule"
echo "#"
echo "############################################"
kubectl taint nodes win1 win=true:NoSchedule
kubectl taint nodes win2 win=true:NoSchedule


echo "#################################################################"
echo "#"
echo "# Ansible installation"
echo "#"
echo "#################################################################"
dnf install -y python-pip
pip install ansible-core==2.15.12 netapp-lib
ansible-galaxy collection install netapp.ontap --ignore-certs


echo "#################################################################"
echo "#"
echo "# Secondary SVM Creation & Peering"
echo "#"
echo "#################################################################"
mkdir -p /etc/ansible
if [ -f /etc/ansible/hosts ]; then mv /etc/ansible/hosts /etc/ansible/hosts.bak; fi;
cp /root/LabNetApp/Kubernetes_v6/Addendum/Addenda13/hosts /etc/ansible/ 

ansible-playbook /root/LabNetApp/Kubernetes_v6/Addendum/Addenda13/svm_secondary_create.yaml

ansible-playbook /root/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario24/svm_peering.yaml


echo "#################################################################"
echo "#"
echo "# S3 SVM & Bucket Creation"
echo "#"
echo "#################################################################"
ansible-playbook /root/LabNetApp/Kubernetes_v6/Addendum/Addenda09/svm_S3_setup.yaml > /root/ansible_S3_SVM_result.txt


echo "#################################################################"
echo "#"
echo "# Secondary K8S cluster creation"
echo "#"
echo "#################################################################"
scp -p /root/LabNetApp/Kubernetes_v6/Addendum/Addenda12/all_in_one.sh rhel5:all_in_one_K8S_setup.sh
ssh -o "StrictHostKeyChecking no" root@rhel5 -t "sh all_in_one_K8S_setup.sh"


echo "#################################################################"
echo "#"
echo "# Trident configuration on the secondary cluster"
echo "#"
echo "#################################################################"

cat << EOF | kubectl apply --kubeconfig=/root/.kube/config_rhel5 -f -
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