#!/bin/bash

set -Eeuo pipefail
trap 'echo "ERROR at line $LINENO while running: $BASH_COMMAND"; kubectl get nodes 2>/dev/null || true' ERR

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

check_local_kubeadm_version() {
  local expected=$1
  local current
  current=$(kubeadm version -o short 2>/dev/null || true)
  if [ "$current" != "$expected" ]; then
    echo "ERROR: local kubeadm version is '$current' but expected '$expected'"
    return 1
  fi
}

check_remote_kubeadm_version() {
  local host=$1; local expected=$2
  local current
  current=$(ssh -o "StrictHostKeyChecking no" "root@$host" "kubeadm version -o short" 2>/dev/null | tr -d '\r' || true)
  if [ "$current" != "$expected" ]; then
    echo "ERROR: kubeadm version on $host is '$current' but expected '$expected'"
    return 1
  fi
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

echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.30"
echo "#######################################################################################################"

sed -i 's/1.29/1.30/' /etc/yum.repos.d/kubernetes.repo
# yum list --showduplicates kubeadm --disableexcludes=kubernetes
yum install -y kubeadm-1.30.14-150500.1.1 kubelet-1.30.14-150500.1.1 kubectl-1.30.14-150500.1.1 --disableexcludes=kubernetes
# kubeadm upgrade plan
check_local_kubeadm_version "v1.30.14"
sleep_with_progress 10
kubeadm upgrade apply v1.30.14 -y
kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
systemctl daemon-reload && systemctl restart kubelet
kubectl wait --for=condition=Ready node/rhel3 --timeout=300s
kubectl uncordon rhel3
sleep_with_progress 60


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.30"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/1.29/1.30/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.30.14-150500.1.1 kubelet-1.30.14-150500.1.1 kubectl-1.30.14-150500.1.1 --disableexcludes=kubernetes
check_remote_kubeadm_version "rhel1" "v1.30.14"
sleep_with_progress 10
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart kubelet"
kubectl wait --for=condition=Ready node/rhel1 --timeout=300s
kubectl uncordon rhel1
sleep_with_progress 60


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.30"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/1.29/1.30/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.30.14-150500.1.1 kubelet-1.30.14-150500.1.1 kubectl-1.30.14-150500.1.1 --disableexcludes=kubernetes
check_remote_kubeadm_version "rhel2" "v1.30.14"
sleep_with_progress 10
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
kubectl drain rhel2 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl daemon-reload && systemctl restart kubelet"
kubectl wait --for=condition=Ready node/rhel2 --timeout=300s
kubectl uncordon rhel2
sleep_with_progress 60

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

MAX_POD_WAIT_SECONDS=1200
elapsed_wait=0
while true; do
  pod_lines=$(kubectl get pods -A --no-headers 2>/dev/null || true)
  running=$(printf "%s\n" "$pod_lines" | awk '$4=="Running" {c++} END {print c+0}')
  pending=$(printf "%s\n" "$pod_lines" | awk '$4=="Pending" {c++} END {print c+0}')
  failed=$(printf "%s\n" "$pod_lines" | awk '$4=="Failed" {c++} END {print c+0}')
  crashloop=$(printf "%s\n" "$pod_lines" | awk '$4=="CrashLoopBackOff" {c++} END {print c+0}')
  imagepull=$(printf "%s\n" "$pod_lines" | awk '$4=="ImagePullBackOff" {c++} END {print c+0}')
  other=$(printf "%s\n" "$pod_lines" | awk '$4!="Running" && $4!="Pending" && $4!="Failed" && $4!="CrashLoopBackOff" && $4!="ImagePullBackOff" {c++} END {print c+0}')
  total=$((running + pending + failed + crashloop + imagepull + other))
  
  printf "\r[Running: %d | Pending: %d | Failed: %d | CrashLoop: %d | ImagePullErr: %d | Other: %d] Total: %d" \
    "$running" "$pending" "$failed" "$crashloop" "$imagepull" "$other" "$total"
  
  if [ "$pending" -eq 0 ] && [ "$failed" -eq 0 ] && [ "$crashloop" -eq 0 ] && [ "$imagepull" -eq 0 ] && [ "$other" -eq 0 ]; then
    echo
    echo "✓ All pods are Running!"
    break
  fi

  if [ "$elapsed_wait" -ge "$MAX_POD_WAIT_SECONDS" ]; then
    echo
    echo "ERROR: Timed out after ${MAX_POD_WAIT_SECONDS}s waiting for all pods to be Running"
    kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" {print}' || true
    exit 1
  fi
  
  sleep 1
  elapsed_wait=$((elapsed_wait + 1))
done


echo
echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.30 finished"
echo "#######################################################################################################"

kubectl get nodes