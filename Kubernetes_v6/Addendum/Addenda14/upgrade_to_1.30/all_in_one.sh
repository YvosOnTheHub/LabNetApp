#!/bin/bash

KUBELET_KUBEADM_CONF="/var/lib/kubelet/kubeadm-flags.env"
CURRENT_IMAGE=$(grep -i KUBELET_KUBEADM_ARGS /var/lib/kubelet/kubeadm-flags.env | awk -F ':' '{print $3}' | tr -d '"')
if [ "$CURRENT_IMAGE" != "3.10" ]; then
  echo "#######################################################################################################"
  echo "Upgrading Sandbox Image to Pause 3.10 on RHEL3"
  echo "#######################################################################################################"
  crictl pull registry.k8s.io/pause:3.10
  sed -i 's/3.9/3.10/' /var/lib/kubelet/kubeadm-flags.env
  systemctl daemon-reload && systemctl restart kubelet
  sleep 10s

  echo "#######################################################################################################"
  echo "Upgrading Sandbox Image to Pause 3.10 on RHEL2"
  echo "#######################################################################################################"
  ssh -o "StrictHostKeyChecking no" root@rhel2 crictl pull registry.k8s.io/pause:3.10
  ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/3.9/3.10/' /var/lib/kubelet/kubeadm-flags.env"
  ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl daemon-reload && systemctl restart kubelet"
  sleep 10s

  echo "#######################################################################################################"
  echo "Upgrading Sandbox Image to Pause 3.10 on RHEL1"
  echo "#######################################################################################################"
  ssh -o "StrictHostKeyChecking no" root@rhel1 crictl pull registry.k8s.io/pause:3.10
  ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/3.9/3.10/' /var/lib/kubelet/kubeadm-flags.env"
  ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart kubelet"
  sleep 10s
fi

echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.30"
echo "#######################################################################################################"

sed -i 's/1.29/1.30/' /etc/yum.repos.d/kubernetes.repo
#yum list --showduplicates kubeadm --disableexcludes=kubernetes
yum install -y kubeadm-1.30.14-150500.1.1 kubelet-1.30.14-150500.1.1 kubectl-1.30.14-150500.1.1 --disableexcludes=kubernetes
# kubeadm upgrade plan
kubeadm upgrade apply v1.30.14 -y
kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
systemctl daemon-reload && systemctl restart kubelet
sleep 45s
kubectl uncordon rhel3
sleep 15s


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.30"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/1.29/1.30/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.30.14-150500.1.1 kubelet-1.30.14-150500.1.1 kubectl-1.30.14-150500.1.1 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart kubelet"
kubectl uncordon rhel1
sleep 60s


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.30"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/1.29/1.30/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.30.14-150500.1.1 kubelet-1.30.14-150500.1.1 kubectl-1.30.14-150500.1.1 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
kubectl drain rhel2 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl daemon-reload && systemctl restart kubelet"
kubectl uncordon rhel2

wait_period=0
while true
do
  wait_period=$(($wait_period+10))
  if [ $wait_period -gt 60 ];then
    break
    else
      echo "sleeping a bit ..."
      sleep 10
    fi
done

echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.30 finished"
echo "#######################################################################################################"

kubectl get nodes