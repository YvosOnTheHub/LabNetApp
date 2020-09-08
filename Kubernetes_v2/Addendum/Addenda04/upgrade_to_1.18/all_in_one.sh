#!/bin/bash

echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.18"
echo "#######################################################################################################"

yum install -y kubeadm-1.18.5-0 --disableexcludes=kubernetes
kubeadm upgrade apply v1.18.5 -y
yum install -y kubelet-1.18.5-0 kubectl-1.18.5-0 --disableexcludes=kubernetes
systemctl restart kubelet
systemctl daemon-reload
sleep 30s

echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.18"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.18.5-0 --disableexcludes=kubernetesclear
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubelet-1.18.5-0 kubectl-1.18.5-0 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl restart kubelet
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
sleep 30s

echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.18"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.18.5-0 --disableexcludes=kubernetesclear
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubelet-1.18.5-0 kubectl-1.18.5-0 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel2 systemctl restart kubelet
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
sleep 30s

if [ $(kubectl get nodes | wc -l) = 5 ]
then
  echo "#######################################################################################################"
  echo "Upgrading Kubernetes Worker RHEL4 to K8s 1.18"
  echo "#######################################################################################################"

  ssh -o "StrictHostKeyChecking no" root@rhel4 yum install -y kubeadm-1.18.5-0 --disableexcludes=kubernetesclear
  ssh -o "StrictHostKeyChecking no" root@rhel4 kubeadm upgrade node 
  ssh -o "StrictHostKeyChecking no" root@rhel4 yum install -y kubelet-1.18.5-0 kubectl-1.18.5-0 --disableexcludes=kubernetes
  ssh -o "StrictHostKeyChecking no" root@rhel4 systemctl restart kubelet
  ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
  sleep 30s
fi

echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.18 finished"
echo "#######################################################################################################"

kubectl get nodes