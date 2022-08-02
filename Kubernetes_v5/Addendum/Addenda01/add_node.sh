#!/bin/bash

# PARAMETER1: name of the host to add

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Host to add to the cluster"
    exit 0
fi

# Number of nodes at the end of the script
TARGET=$(kubectl get nodes | grep Ready | wc -l)
TARGET=$((++TARGET))

ssh -o "StrictHostKeyChecking no" root@$1 "cat <<EOF >  /etc/modules-load.d/k8s.conf
br_netfilter
EOF"

ssh -o "StrictHostKeyChecking no" root@$1 "cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF"

ssh -o "StrictHostKeyChecking no" root@$1 "sysctl --system"

ssh -o "StrictHostKeyChecking no" root@$1 "setenforce 0"
ssh -o "StrictHostKeyChecking no" root@$1 "sed -i 's/^SELINUX=enforcing$/SELINUX=Disabled/' /etc/selinux/config"
ssh -o "StrictHostKeyChecking no" root@$1 "swapoff -a"
ssh -o "StrictHostKeyChecking no" root@$1 "cp /etc/fstab /etc/fstab.bak"
ssh -o "StrictHostKeyChecking no" root@$1 "sed -e '/swap/ s/^#*/#/g' -i /etc/fstab"

ssh -o "StrictHostKeyChecking no" root@$1 "cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF"

ssh -o "StrictHostKeyChecking no" root@$1 yum install -y kubelet-1.22.3 kubeadm-1.22.3 kubectl-1.22.3 --nogpgcheck
ssh -o "StrictHostKeyChecking no" root@$1 kubeadm reset -f

KUBEADMJOIN=$(kubeadm token create --print-join-command)
ssh -o "StrictHostKeyChecking no" root@$1 $KUBEADMJOIN

while [ $(kubectl get nodes | grep Ready | wc -l) -ne $TARGET ]
do
  echo "sleeping a bit - waiting for all nodes to be ready ..."
  sleep 5
done