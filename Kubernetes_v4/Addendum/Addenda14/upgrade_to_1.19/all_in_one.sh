#!/bin/bash

echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.19"
echo "#######################################################################################################"

yum install -y kubeadm-1.19.16-0 kubelet-1.19.16-0 kubectl-1.19.16-0 --disableexcludes=kubernetes
kubeadm upgrade apply v1.19.16 -y
sed -i 's/VolumeSnapshotDataSource/GenericEphemeralVolume/' /etc/sysconfig/kubelet
systemctl daemon-reload
systemctl restart kubelet
sleep 30s

echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.19"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.19.16-0 kubelet-1.19.16-0 kubectl-1.19.16-0 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
ssh -o "StrictHostKeyChecking no" root@rhel1 sed -i 's/$/--feature-gates=GenericEphemeralVolume=true/' /etc/sysconfig/kubelet
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl daemon-reload
ssh -o "StrictHostKeyChecking no" root@rhel1 systemctl restart kubelet
sleep 30s

echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.19"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.19.16-0 kubelet-1.19.16-0 kubectl-1.19.16-0 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
ssh -o "StrictHostKeyChecking no" root@rhel2 sed -i 's/$/--feature-gates=GenericEphemeralVolume=true/' /etc/sysconfig/kubelet
ssh -o "StrictHostKeyChecking no" root@rhel2 systemctl daemon-reload
ssh -o "StrictHostKeyChecking no" root@rhel2 systemctl restart kubelet
sleep 30s

if [ $(kubectl get nodes | wc -l) = 5 ]
then
  echo "#######################################################################################################"
  echo "Upgrading Kubernetes Worker RHEL4 to K8s 1.19"
  echo "#######################################################################################################"

  ssh -o "StrictHostKeyChecking no" root@rhel4 yum install -y kubeadm-1.19.16-0 kubelet-1.19.16-0 kubectl-1.19.16-0 --disableexcludes=kubernetesclear
  ssh -o "StrictHostKeyChecking no" root@rhel4 kubeadm upgrade node 
  ssh -o "StrictHostKeyChecking no" root@rhel4 sed -i 's/$/--feature-gates=GenericEphemeralVolume=true/' /etc/sysconfig/kubelet
  ssh -o "StrictHostKeyChecking no" root@rhel4 systemctl daemon-reload
  ssh -o "StrictHostKeyChecking no" root@rhel4 systemctl restart kubelet
  sleep 30s
fi

echo "#######################################################################################################"
echo "Enable Generic Ephemeral Volumes Feature"
echo "#######################################################################################################"

sed -i '/apiserver.key/a \ \ \ \ - --feature-gates=GenericEphemeralVolume=true' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/port=0/a \ \ \ \ - --feature-gates=GenericEphemeralVolume=true' /etc/kubernetes/manifests/kube-scheduler.yaml
sed -i '/use-service-account-credentials=true/a \ \ \ \ - --feature-gates=GenericEphemeralVolume=true' /etc/kubernetes/manifests/kube-controller-manager.yaml

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

until [[ $(kubectl -n kube-system get pod kube-controller-manager-rhel3 -o=json | grep Ephemeral | wc -l) -eq 1 ]]; do
  echo "waiting for controller manager to be ready ..."
  sleep 5
  until [[ $(kubectl -n kube-system get pod kube-controller-manager-rhel3 -o=jsonpath='{.status.containerStatuses[0].ready}') == 'true' ]]; do
    echo "waiting for controller manager to be ready ..."
    sleep 5
  done
done

until [[ $(kubectl -n kube-system get pod kube-scheduler-rhel3 -o=json | grep Ephemeral | wc -l) -eq 1 ]]; do
  echo "waiting for scheduler to be ready ..."
  sleep 5
  until [[ $(kubectl -n kube-system get pod kube-scheduler-rhel3 -o=jsonpath='{.status.containerStatuses[0].ready}') == 'true' ]]; do
    echo "waiting for scheduler to be ready ..."
    sleep 5
  done
done

echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.19 finished & GenericEphemeralVolume feature gate enabled"
echo "#######################################################################################################"

kubectl get nodes