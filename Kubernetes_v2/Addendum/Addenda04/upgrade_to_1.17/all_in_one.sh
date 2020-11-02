#!/bin/bash

echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.17"
echo "#######################################################################################################"

yum install -y kubeadm-1.17.11-0 --disableexcludes=kubernetes
kubeadm upgrade apply v1.17.11 -y
yum install -y kubelet-1.17.11-0 kubectl-1.17.11-0 --disableexcludes=kubernetes
systemctl restart kubelet
systemctl daemon-reload
sleep 30s

echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.17"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.17.11-0 --disableexcludes=kubernetesclear
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubelet-1.17.11-0 kubectl-1.17.11-0 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl restart kubelet
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
sleep 30s

echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.17"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.17.11-0 --disableexcludes=kubernetesclear
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubelet-1.17.11-0 kubectl-1.17.11-0 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel2 systemctl restart kubelet
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
sleep 30s

if [ $(kubectl get nodes | wc -l) = 5 ]
then
  echo "#######################################################################################################"
  echo "Upgrading Kubernetes Worker RHEL4 to K8s 1.17"
  echo "#######################################################################################################"

  ssh -o "StrictHostKeyChecking no" root@rhel4 yum install -y kubeadm-1.17.11-0 --disableexcludes=kubernetesclear
  ssh -o "StrictHostKeyChecking no" root@rhel4 kubeadm upgrade node 
  ssh -o "StrictHostKeyChecking no" root@rhel4 yum install -y kubelet-1.17.11-0 kubectl-1.17.11-0 --disableexcludes=kubernetes
  ssh -o "StrictHostKeyChecking no" root@rhel4 systemctl restart kubelet
  ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
  sleep 30s
fi

echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.17 finished"
echo "#######################################################################################################"

kubectl get nodes

echo "#######################################################################################################"
echo "Add Region & Zone labels to Kubernetes nodes"
echo "#######################################################################################################"

kubectl label node rhel1 "topology.kubernetes.io/region=trident"
kubectl label node rhel2 "topology.kubernetes.io/region=trident"
kubectl label node rhel3 "topology.kubernetes.io/region=trident"

kubectl label node rhel1 "topology.kubernetes.io/zone=west"
kubectl label node rhel2 "topology.kubernetes.io/zone=east"
kubectl label node rhel3 "topology.kubernetes.io/zone=admin"

if [ $(kubectl get nodes | wc -l) = 5 ]
then
  kubectl label node rhel4 "topology.kubernetes.io/region=trident"
  kubectl label node rhel4 "topology.kubernetes.io/zone=north"
fi