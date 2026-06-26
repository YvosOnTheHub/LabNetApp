#!/bin/bash

##############################################################
# sleep_with_progress()
# Sleeps for the specified duration while displaying remaining
# time and an animated progress indicator every second
##############################################################
sleep_with_progress() {
  local duration=$1
  local elapsed=0
  local frame_chars=("/" "|" "\\" "-")
  
  while [ $elapsed -lt $duration ]; do
    printf "\rSleeping... %d seconds remaining [${frame_chars[$((elapsed % 4))]}]" $((duration - elapsed))
    sleep 1
    elapsed=$((elapsed + 1))
  done
  printf "\r%*s\r" $((${#1} + 35)) ""  # Clear the line
}

if kubectl get namespace kubevirt >/dev/null 2>&1; then
  echo "#######################################################################################################" 
  echo "Scaling down KubeVirt components running on the control plane to avoid issues during upgrade"
  echo "#######################################################################################################"
  for deploy in virt-operator virt-api virt-controller; do
    if kubectl -n kubevirt get deploy "$deploy" >/dev/null 2>&1; then
      kubectl -n kubevirt scale deploy "$deploy" --replicas=0
    fi
  done
fi

echo
echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.31"
echo "#######################################################################################################"

sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo
# yum list --showduplicates kubeadm --disableexcludes=kubernetes
yum install -y kubeadm-1.31.14-150500.1.1 kubelet-1.31.14-150500.1.1 kubectl-1.31.14-150500.1.1 --disableexcludes=kubernetes
# kubeadm upgrade plan
kubeadm upgrade apply v1.31.14 -y
kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
systemctl daemon-reload && systemctl restart kubelet
kubectl wait --for=condition=Ready node/rhel3 --timeout=300s
kubectl uncordon rhel3
sleep_with_progress "30"


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.31"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.31.14-150500.1.1 kubelet-1.31.14-150500.1.1 kubectl-1.31.14-150500.1.1 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart kubelet"
kubectl wait --for=condition=Ready node/rhel1 --timeout=300s
kubectl uncordon rhel1
sleep_with_progress "30"


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.31"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.31.14-150500.1.1 kubelet-1.31.14-150500.1.1 kubectl-1.31.14-150500.1.1 --disableexcludes=kubernetes
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
kubectl drain rhel2 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl daemon-reload && systemctl restart kubelet"
kubectl wait --for=condition=Ready node/rhel2 --timeout=300s
kubectl uncordon rhel2
sleep_with_progress "60"

if kubectl get namespace kubevirt >/dev/null 2>&1; then
  echo
  echo "#######################################################################################################" 
  echo "Scaling KubeVirt components back up"
  echo "#######################################################################################################"
  for deploy in virt-operator virt-api virt-controller; do
    if kubectl -n kubevirt get deploy "$deploy" >/dev/null 2>&1; then
      kubectl -n kubevirt scale deploy "$deploy" --replicas=2
    fi
  done
fi


echo
echo "#######################################################################################################"
echo "Waiting for all pods to reach Running state..."
echo "#######################################################################################################"

while true; do
  running=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="Running" {c++} END {print c+0}')
  pending=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="Pending" {c++} END {print c+0}')
  failed=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="Failed" {c++} END {print c+0}')
  crashloop=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="CrashLoopBackOff" {c++} END {print c+0}')
  imagepull=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4=="ImagePullBackOff" {c++} END {print c+0}')
  other=$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Pending" && $4!="Failed" && $4!="CrashLoopBackOff" && $4!="ImagePullBackOff" {c++} END {print c+0}')
  total=$((running + pending + failed + crashloop + imagepull + other))
  
  printf "\r[Running: %d | Pending: %d | Failed: %d | CrashLoop: %d | ImagePullErr: %d | Other: %d] Total: %d" \
    "$running" "$pending" "$failed" "$crashloop" "$imagepull" "$other" "$total"
  
  if [ "$pending" -eq 0 ] && [ "$failed" -eq 0 ] && [ "$crashloop" -eq 0 ] && [ "$imagepull" -eq 0 ] && [ "$other" -eq 0 ]; then
    echo
    echo "✓ All pods are Running!"
    break
  fi
  
  sleep 1
done

echo
echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.30 finished"
echo "#######################################################################################################"

kubectl get nodes