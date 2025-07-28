#!/bin/bash

echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.31"
echo "#######################################################################################################"

sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo
#yum list --showduplicates kubeadm --disableexcludes=kubernetes
yum install -y kubeadm-1.31.11-150500.1.1 kubelet-1.31.11-150500.1.1 kubectl-1.31.11-150500.1.1 --disableexcludes=kubernetes
# kubeadm upgrade plan
kubeadm upgrade apply v1.31.11 -y
kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
systemctl daemon-reload && systemctl restart kubelet
sleep 45s
kubectl uncordon rhel3
sleep 15s


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.31"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.31.11-150500.1.1 kubelet-1.31.11-150500.1.1 kubectl-1.31.11-150500.1.1 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart kubelet"
kubectl uncordon rhel1
sleep 60s


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.31"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.31.11-150500.1.1 kubelet-1.31.11-150500.1.1 kubectl-1.31.11-150500.1.1 --disableexcludes=kubernetes
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