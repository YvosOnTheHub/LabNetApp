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

check_local_pause_image() {
  local expected=$1
  local current
  current=$(crio config 2>/dev/null | awk -F '"' '/pause_image/ {print $2; exit}' || echo "")
  if [ "$current" != "$expected" ]; then
    echo "ERROR: local CRI-O pause image is '$current' but expected '$expected'"
    return 1
  fi
}

check_remote_pause_image() {
  local host=$1; local expected=$2
  local current
  current=$(ssh -o "StrictHostKeyChecking no" "root@$host" "crio config 2>/dev/null | awk -F '\"' '/pause_image/ {print \$2; exit}' || echo ''" 2>/dev/null | tr -d '\r' || echo "")
  if [ "$current" != "$expected" ]; then
    echo "ERROR: CRI-O pause image on $host is '$current' but expected '$expected'"
    return 1
  fi
}

KV_REPLICA_FILE="/tmp/addenda14-kubevirt-replicas.$$"

scale_down_kubevirt() {
  rm -f "$KV_REPLICA_FILE"
  if ! kubectl get namespace kubevirt >/dev/null 2>&1; then
    return 0
  fi
  echo "#######################################################################################################"
  echo "Scaling down KubeVirt components running on the control plane to avoid issues during upgrade"
  echo "#######################################################################################################"
  for deploy in virt-operator virt-api virt-controller; do
    if kubectl -n kubevirt get deploy "$deploy" >/dev/null 2>&1; then
      replicas=$(kubectl -n kubevirt get deploy "$deploy" -o jsonpath='{.spec.replicas}')
      printf '%s %s\n' "$deploy" "${replicas:-1}" >> "$KV_REPLICA_FILE"
      kubectl -n kubevirt scale deploy "$deploy" --replicas=0
    fi
  done
}

scale_up_kubevirt() {
  if [ ! -f "$KV_REPLICA_FILE" ]; then
    return 0
  fi
  echo
  echo "#######################################################################################################"
  echo "Scaling KubeVirt components back up"
  echo "#######################################################################################################"
  while read -r deploy replicas; do
    [ -n "${deploy:-}" ] || continue
    kubectl -n kubevirt scale deploy "$deploy" --replicas="$replicas"
  done < "$KV_REPLICA_FILE" || true
  rm -f "$KV_REPLICA_FILE"
}

wait_for_healthy_pods() {
  echo
  echo "#######################################################################################################"
  echo "Waiting for all pods to reach Running or Succeeded state..."
  echo "#######################################################################################################"

  local MAX_POD_WAIT_SECONDS=1200
  local elapsed_wait=0
  local pod_lines running pending failed crashloop imagepull succeeded other total
  while true; do
    pod_lines=$(kubectl get pods -A --no-headers 2>/dev/null || true)
    running=$(printf "%s\n" "$pod_lines" | awk '$4=="Running" {c++} END {print c+0}')
    pending=$(printf "%s\n" "$pod_lines" | awk '$4=="Pending" {c++} END {print c+0}')
    failed=$(printf "%s\n" "$pod_lines" | awk '$4=="Failed" {c++} END {print c+0}')
    crashloop=$(printf "%s\n" "$pod_lines" | awk '$4=="CrashLoopBackOff" {c++} END {print c+0}')
    imagepull=$(printf "%s\n" "$pod_lines" | awk '$4=="ImagePullBackOff" {c++} END {print c+0}')
    succeeded=$(printf "%s\n" "$pod_lines" | awk '$4=="Succeeded" || $4=="Completed" {c++} END {print c+0}')
    other=$(printf "%s\n" "$pod_lines" | awk '$4!="Running" && $4!="Pending" && $4!="Failed" && $4!="CrashLoopBackOff" && $4!="ImagePullBackOff" && $4!="Succeeded" && $4!="Completed" {c++} END {print c+0}')
    total=$((running + pending + failed + crashloop + imagepull + succeeded + other))

    printf "\r[Running: %d | Succeeded: %d | Pending: %d | Failed: %d | CrashLoop: %d | ImagePullErr: %d | Other: %d] Total: %d" \
      "$running" "$succeeded" "$pending" "$failed" "$crashloop" "$imagepull" "$other" "$total"

    if [ "$pending" -eq 0 ] && [ "$failed" -eq 0 ] && [ "$crashloop" -eq 0 ] && [ "$imagepull" -eq 0 ] && [ "$other" -eq 0 ]; then
      echo
      echo "All pods are Running or Succeeded."
      break
    fi

    if [ "$elapsed_wait" -ge "$MAX_POD_WAIT_SECONDS" ]; then
      echo
      echo "ERROR: Timed out after ${MAX_POD_WAIT_SECONDS}s waiting for all pods to be Running or Succeeded"
      kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Succeeded" && $4!="Completed" {print}' || true
      exit 1
    fi

    sleep 1
    elapsed_wait=$((elapsed_wait + 1))
  done
}

scale_down_kubevirt

echo
PAUSE_IMAGE_TARGET="registry.k8s.io/pause:3.10"
CURRENT_IMAGE=$(crio config 2>/dev/null | awk -F '"' '/pause_image/ {print $2; exit}' || echo "")
if [ "$CURRENT_IMAGE" != "$PAUSE_IMAGE_TARGET" ]; then
  echo "#######################################################################################################"
  echo "Upgrading Sandbox Image to Pause 3.10 on RHEL3"
  echo "#######################################################################################################"
  kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
  crictl pull "$PAUSE_IMAGE_TARGET"
  printf '%s\n' '[crio.image]' "pause_image = \"$PAUSE_IMAGE_TARGET\"" > /etc/crio/crio.conf.d/99-pause-image.conf
  systemctl daemon-reload && systemctl restart crio && systemctl restart kubelet
  kubectl wait --for=condition=Ready node/rhel3 --timeout=300s
  kubectl uncordon rhel3
  check_local_pause_image "$PAUSE_IMAGE_TARGET"

  echo "#######################################################################################################"
  echo "Upgrading Sandbox Image to Pause 3.10 on RHEL1"
  echo "#######################################################################################################"
  kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
  ssh -o "StrictHostKeyChecking no" root@rhel1 "crictl pull $PAUSE_IMAGE_TARGET"
  ssh -o "StrictHostKeyChecking no" root@rhel1 "printf '%s\n' '[crio.image]' 'pause_image = \"$PAUSE_IMAGE_TARGET\"' > /etc/crio/crio.conf.d/99-pause-image.conf"
  ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart crio && systemctl restart kubelet"
  kubectl wait --for=condition=Ready node/rhel1 --timeout=300s
  kubectl uncordon rhel1
  check_remote_pause_image "rhel1" "$PAUSE_IMAGE_TARGET"

  echo "#######################################################################################################"
  echo "Upgrading Sandbox Image to Pause 3.10 on RHEL2"
  echo "#######################################################################################################"
  kubectl drain rhel2 --ignore-daemonsets --delete-emptydir-data
  ssh -o "StrictHostKeyChecking no" root@rhel2 "crictl pull $PAUSE_IMAGE_TARGET"
  ssh -o "StrictHostKeyChecking no" root@rhel2 "printf '%s\n' '[crio.image]' 'pause_image = \"$PAUSE_IMAGE_TARGET\"' > /etc/crio/crio.conf.d/99-pause-image.conf"
  ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl daemon-reload && systemctl restart crio && systemctl restart kubelet"
  kubectl wait --for=condition=Ready node/rhel2 --timeout=300s
  kubectl uncordon rhel2
  check_remote_pause_image "rhel2" "$PAUSE_IMAGE_TARGET"
fi

echo
echo "#######################################################################################################"
echo "Upgrading Kubernetes Master RHEL3 to K8s 1.31"
echo "#######################################################################################################"

sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo
# yum list --showduplicates kubeadm --disableexcludes=kubernetes
yum install -y kubeadm-1.31.14-150500.1.1 kubelet-1.31.14-150500.1.1 kubectl-1.31.14-150500.1.1 --disableexcludes=kubernetes
# kubeadm upgrade plan
check_local_kubeadm_version "v1.31.14"
sleep_with_progress 10
# The kubeadm health check job only gets 15s to complete, which is often too short in the lab
kubectl -n kube-system get jobs -o name 2>/dev/null | grep upgrade-health-check | xargs -r kubectl -n kube-system delete || true
kubeadm upgrade apply v1.31.14 --ignore-preflight-errors=CreateJob -y
kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
systemctl daemon-reload && systemctl restart kubelet
kubectl wait --for=condition=Ready node/rhel3 --timeout=300s
kubectl uncordon rhel3
sleep_with_progress 60


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL1 to K8s 1.31"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel1 yum install -y kubeadm-1.31.14-150500.1.1 kubelet-1.31.14-150500.1.1 kubectl-1.31.14-150500.1.1 --disableexcludes=kubernetes
check_remote_kubeadm_version "rhel1" "v1.31.14"
sleep_with_progress 10
ssh -o "StrictHostKeyChecking no" root@rhel1 kubeadm upgrade node 
kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl daemon-reload && systemctl restart kubelet"
kubectl wait --for=condition=Ready node/rhel1 --timeout=300s
kubectl uncordon rhel1
sleep_with_progress 60


echo "#######################################################################################################"
echo "Upgrading Kubernetes Worker RHEL2 to K8s 1.31"
echo "#######################################################################################################"

ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo"
ssh -o "StrictHostKeyChecking no" root@rhel2 yum install -y kubeadm-1.31.14-150500.1.1 kubelet-1.31.14-150500.1.1 kubectl-1.31.14-150500.1.1 --disableexcludes=kubernetes
check_remote_kubeadm_version "rhel2" "v1.31.14"
sleep_with_progress 10
ssh -o "StrictHostKeyChecking no" root@rhel2 kubeadm upgrade node 
kubectl drain rhel2 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl daemon-reload && systemctl restart kubelet"
kubectl wait --for=condition=Ready node/rhel2 --timeout=300s
kubectl uncordon rhel2
sleep_with_progress 60

scale_up_kubevirt

wait_for_healthy_pods

echo
echo "#######################################################################################################"
echo "Upgrade to Kubernetes 1.31 finished"
echo "#######################################################################################################"

kubectl get nodes