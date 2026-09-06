#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly TARGET_VERSION="1.36.4"
readonly TARGET_VERSION_V="v${TARGET_VERSION}"
readonly TARGET_MINOR="${TARGET_VERSION%.*}"
readonly CONTROL_PLANE="rhel3"
readonly CONTROL_PLANE_IP="192.168.0.63"
readonly WORKERS=("rhel1" "rhel2")
readonly EXPECTED_NODES=("rhel1" "rhel2" "rhel3")
readonly CRI_SOCKET="unix:///var/run/crio/crio.sock"
readonly PAUSE_IMAGE="registry.k8s.io/pause:3.10"

# Values captured from the primary cluster on 2026-09-05.
readonly POD_SUBNET="192.168.24.0/21"
readonly SERVICE_SUBNET="10.96.0.0/12"
readonly DNS_DOMAIN="cluster.local"
readonly CALICO_VERSION="v3.27.3"
readonly METALLB_CHART_VERSION="0.14.5"
readonly METALLB_POOL="192.168.0.210-192.168.0.219"
readonly LAB_REGISTRY="registry.demo.netapp.com"
readonly LAB_REGISTRY_USER="registryuser"
readonly LAB_REGISTRY_PASSWORD="Netapp1!"

readonly SSH_OPTIONS=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=no
)

BACKUP_ONLY=false
ASSUME_YES=false
RESUME_FROM=""
PHASE="initialization"
BACKUP_DIR=""

error_handler() {
  local exit_code=$?
  echo >&2
  echo "ERROR: phase '${PHASE}' failed at line ${BASH_LINENO[0]}: ${BASH_COMMAND}" >&2
  if [[ -n "${BACKUP_DIR}" ]]; then
    echo "Configuration backup: ${BACKUP_DIR}" >&2
  fi
  exit "$exit_code"
}
trap error_handler ERR

usage() {
  cat <<EOF
Usage: $(basename "$0") [--backup-only] [--yes-i-understand] [--resume-from PHASE]

Destructively rebuild the primary Kubernetes cluster at ${TARGET_VERSION_V}:
  control plane: ${CONTROL_PLANE} (${CONTROL_PLANE_IP})
  Linux workers: ${WORKERS[*]}
  Calico:        ${CALICO_VERSION}, VXLAN, BGP disabled
  MetalLB:       ${METALLB_CHART_VERSION}, pool ${METALLB_POOL}

Windows nodes are removed from the Kubernetes API and are not reset or rejoined.
All Kubernetes API objects and workloads in the primary cluster are destroyed.

Options:
  --backup-only        Export configuration without changing the cluster.
  --yes-i-understand   Skip the interactive destructive confirmation.
  --resume-from PHASE  Continue an interrupted rebuild without resetting again.
                       PHASE is one of: calico, join, metallb, verify.
  -h, --help           Show this help.
EOF
}

log_section() {
  echo
  echo "#######################################################################################################"
  echo "# $*"
  echo "#######################################################################################################"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command '$1' is not installed" >&2
    exit 1
  }
}

remote() {
  local host=$1
  shift
  ssh "${SSH_OPTIONS[@]}" "root@${host}" "$@"
}

parse_arguments() {
  while (($#)); do
    case "$1" in
      --backup-only)
        BACKUP_ONLY=true
        ;;
      --yes-i-understand)
        ASSUME_YES=true
        ;;
      --resume-from)
        shift
        RESUME_FROM=${1:-}
        case "$RESUME_FROM" in
          calico|join|metallb|verify)
            ;;
          *)
            echo "ERROR: --resume-from expects calico, join, metallb or verify" >&2
            exit 2
            ;;
        esac
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: unknown argument '$1'" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

preflight() {
  PHASE="preflight checks"
  log_section "Preflight checks"

  if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this script as root on ${CONTROL_PLANE}" >&2
    exit 1
  fi

  local short_hostname
  short_hostname=$(hostname -s)
  if [[ "$short_hostname" != "$CONTROL_PLANE" ]]; then
    echo "ERROR: this script must run on ${CONTROL_PLANE}; current host is ${short_hostname}" >&2
    exit 1
  fi

  local command
  for command in awk cp crictl curl helm hostname ip kubeadm kubectl podman rpm ssh systemctl yum; do
    require_command "$command"
  done

  kubectl cluster-info >/dev/null
  kubectl get node "$CONTROL_PLANE" >/dev/null

  local current_context
  current_context=$(kubectl config current-context)
  echo "kubectl context: ${current_context}"
  echo "API endpoint: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

  local actual_node unexpected_node
  while read -r actual_node; do
    [[ -n "$actual_node" ]] || continue
    case "$actual_node" in
      rhel1|rhel2|rhel3|win1|win2)
        ;;
      *)
        unexpected_node=$actual_node
        echo "ERROR: unexpected node '${unexpected_node}' is joined to the primary cluster." >&2
        echo "Remove it explicitly or add it to this script before rebuilding." >&2
        exit 1
        ;;
    esac
  done < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

  local host
  for host in "${WORKERS[@]}"; do
    echo "Checking root SSH and CRI-O on ${host}..."
    remote "$host" "test \"\$(hostname -s)\" = '${host}' && systemctl is-active --quiet crio"
  done
  systemctl is-active --quiet crio

  echo "Preflight checks passed."
}

backup_optional() {
  local output_file=$1
  shift
  if "$@" >"${BACKUP_DIR}/${output_file}" 2>/dev/null; then
    return
  fi
  rm -f "${BACKUP_DIR}/${output_file}"
  echo "Note: '$*' returned nothing to back up; skipping ${output_file}"
}

backup_configuration() {
  PHASE="configuration backup"
  local timestamp
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  BACKUP_DIR="/root/addenda14-reset-backup-${timestamp}"
  mkdir -p "$BACKUP_DIR"

  log_section "Backing up cluster configuration to ${BACKUP_DIR}"

  kubectl get nodes -o wide >"${BACKUP_DIR}/nodes-wide.txt"
  kubectl get nodes -o yaml >"${BACKUP_DIR}/nodes.yaml"
  kubectl -n kube-system get configmap kubeadm-config \
    -o jsonpath='{.data.ClusterConfiguration}' >"${BACKUP_DIR}/kubeadm-cluster-configuration.yaml"
  printf '\n' >>"${BACKUP_DIR}/kubeadm-cluster-configuration.yaml"

  # Calico and MetalLB are absent when a previous rebuild was interrupted.
  backup_optional "calico-installation.yaml" \
    kubectl get installation.operator.tigera.io default -o yaml
  backup_optional "tigera-operator-deployment.yaml" \
    kubectl -n tigera-operator get deployment tigera-operator -o yaml
  backup_optional "metallb-resources.yaml" \
    kubectl -n metallb-system get ipaddresspools.metallb.io,l2advertisements.metallb.io -o yaml
  backup_optional "metallb-helm-list.txt" \
    helm -n metallb-system list
  backup_optional "metallb-values.yaml" \
    helm -n metallb-system get values metallb --all

  rpm -q kubeadm kubelet kubectl cri-o >"${BACKUP_DIR}/packages-${CONTROL_PLANE}.txt"
  crio config 2>/dev/null >"${BACKUP_DIR}/crio-${CONTROL_PLANE}.conf"

  local host
  for host in "${WORKERS[@]}"; do
    remote "$host" "rpm -q kubeadm kubelet kubectl cri-o" >"${BACKUP_DIR}/packages-${host}.txt"
    remote "$host" "crio config 2>/dev/null" >"${BACKUP_DIR}/crio-${host}.conf"
  done

  if [[ -d /root/.kube ]]; then
    cp -a /root/.kube "${BACKUP_DIR}/root-kube"
  fi
  cp -a /etc/kubernetes "${BACKUP_DIR}/etc-kubernetes" 2>/dev/null || true

  cat >"${BACKUP_DIR}/README.txt" <<EOF
Configuration captured before the destructive Addenda14 cluster rebuild.
Created: $(date --iso-8601=seconds)
Target Kubernetes version: ${TARGET_VERSION_V}
Control plane: ${CONTROL_PLANE}
Workers: ${WORKERS[*]}
Windows nodes were intentionally excluded from the rebuild.
EOF

  echo "Backup complete: ${BACKUP_DIR}"
}

confirm_destruction() {
  if [[ "$ASSUME_YES" == true ]]; then
    return
  fi

  local expected="RESET ${CONTROL_PLANE} TO ${TARGET_VERSION}"
  local answer
  echo
  echo "WARNING: the next step irreversibly deletes the primary cluster and all its API objects."
  echo "The configuration backup is at ${BACKUP_DIR}."
  read -r -p "Type '${expected}' to continue: " answer
  if [[ "$answer" != "$expected" ]]; then
    echo "Confirmation did not match; no destructive action was taken."
    exit 1
  fi
}

verify_target_packages() {
  PHASE="Kubernetes package verification"
  log_section "Ensuring Kubernetes ${TARGET_VERSION} packages are available on all Linux nodes"

  ensure_target_packages_local
  local host
  for host in "${WORKERS[@]}"; do
    remote "$host" "bash -s" <<EOF
set -Eeuo pipefail
if ! rpm -q kubeadm | grep -q '${TARGET_VERSION}'; then
  sed -E -i 's#/v1\.[0-9]+/rpm/#/v${TARGET_MINOR}/rpm/#' /etc/yum.repos.d/kubernetes.repo
  yum install -y \
    'kubeadm-${TARGET_VERSION}*' \
    'kubelet-${TARGET_VERSION}*' \
    'kubectl-${TARGET_VERSION}*' \
    --disableexcludes=kubernetes
fi
test "\$(kubeadm version -o short)" = '${TARGET_VERSION_V}'
EOF
  done
}

ensure_target_packages_local() {
  if ! rpm -q kubeadm | grep -q "$TARGET_VERSION"; then
    sed -E -i "s#/v1\.[0-9]+/rpm/#/v${TARGET_MINOR}/rpm/#" /etc/yum.repos.d/kubernetes.repo
    yum install -y \
      "kubeadm-${TARGET_VERSION}*" \
      "kubelet-${TARGET_VERSION}*" \
      "kubectl-${TARGET_VERSION}*" \
      --disableexcludes=kubernetes
  fi
  [[ "$(kubeadm version -o short)" == "$TARGET_VERSION_V" ]]
}

reset_remote_node() {
  local host=$1
  log_section "Resetting Linux worker ${host}"
  remote "$host" "bash -s" <<EOF
set -Eeuo pipefail
systemctl stop kubelet
kubeadm reset --force --cri-socket '${CRI_SOCKET}'
rm -rf /etc/cni/net.d/* /var/lib/cni /var/lib/calico /var/run/calico
ip link delete vxlan.calico 2>/dev/null || true
for link in \$(ip -o link show | awk -F': ' '\$2 ~ /^cali/ {sub(/@.*/, "", \$2); print \$2}'); do
  ip link delete "\$link" 2>/dev/null || true
done
crictl pull '${PAUSE_IMAGE}'
mkdir -p /etc/crio/crio.conf.d
printf '%s\n' '[crio.image]' 'pause_image = "${PAUSE_IMAGE}"' \
  >/etc/crio/crio.conf.d/99-pause-image.conf
systemctl daemon-reload
systemctl restart crio
systemctl enable kubelet
EOF
}

reset_control_plane() {
  PHASE="control-plane reset"
  log_section "Resetting control plane ${CONTROL_PLANE}"

  systemctl stop kubelet
  kubeadm reset --force --cri-socket "$CRI_SOCKET"
  rm -rf /etc/cni/net.d/* /var/lib/cni /var/lib/calico /var/run/calico
  ip link delete vxlan.calico 2>/dev/null || true

  local link
  while read -r link; do
    [[ -n "$link" ]] || continue
    ip link delete "$link" 2>/dev/null || true
  done < <(ip -o link show | awk -F': ' '$2 ~ /^cali/ {sub(/@.*/, "", $2); print $2}')

  crictl pull "$PAUSE_IMAGE"
  mkdir -p /etc/crio/crio.conf.d
  printf '%s\n' '[crio.image]' "pause_image = \"${PAUSE_IMAGE}\"" \
    >/etc/crio/crio.conf.d/99-pause-image.conf
  systemctl daemon-reload
  systemctl restart crio
  systemctl enable kubelet
}

initialize_control_plane() {
  PHASE="control-plane initialization"
  log_section "Initializing ${CONTROL_PLANE} at Kubernetes ${TARGET_VERSION_V}"

  cat >/root/addenda14-kubeadm-init.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_PLANE_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: ${CRI_SOCKET}
  name: ${CONTROL_PLANE}
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
clusterName: kubernetes
kubernetesVersion: ${TARGET_VERSION_V}
imageRepository: registry.k8s.io
networking:
  dnsDomain: ${DNS_DOMAIN}
  podSubnet: ${POD_SUBNET}
  serviceSubnet: ${SERVICE_SUBNET}
apiServer:
  certSANs:
  - ${CONTROL_PLANE}
  - ${CONTROL_PLANE}.demo.netapp.com
  - ${CONTROL_PLANE_IP}
etcd:
  local:
    dataDir: /var/lib/etcd
EOF

  kubeadm init --config /root/addenda14-kubeadm-init.yaml

  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config_rhel3
  chmod 600 /root/.kube/config_rhel3

  if [[ -f "${BACKUP_DIR}/root-kube/config_rhel5" ]]; then
    cp "${BACKUP_DIR}/root-kube/config_rhel5" /root/.kube/config_rhel5
    KUBECONFIG=/root/.kube/config_rhel3:/root/.kube/config_rhel5 \
      kubectl config view --flatten >/root/.kube/config
  else
    cp /root/.kube/config_rhel3 /root/.kube/config
  fi
  chmod 600 /root/.kube/config
  export KUBECONFIG=/root/.kube/config_rhel3

  kubectl taint node "$CONTROL_PLANE" node-role.kubernetes.io/control-plane:NoSchedule- || true
}

# kubectl wait aborts with an accessor error when .status is still nil, so the
# Established condition is polled instead of waited on.
wait_for_crd_established() {
  local crd=$1
  local timeout=${2:-180}
  local elapsed=0
  local status

  while ((elapsed < timeout)); do
    status=$(kubectl get "crd/${crd}" \
      -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null || true)
    if [[ "$status" == "True" ]]; then
      echo "CRD ${crd} is established."
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "ERROR: CRD ${crd} was not established within ${timeout}s" >&2
  kubectl get "crd/${crd}" -o yaml >&2 || true
  return 1
}

# A freshly joined node is not registered immediately, and kubectl wait fails
# outright on a missing object, so existence is polled before waiting on Ready.
wait_for_node_ready() {
  local node=$1
  local timeout=${2:-600}
  local elapsed=0

  while ((elapsed < timeout)); do
    if kubectl get "node/${node}" >/dev/null 2>&1; then
      kubectl wait --for=condition=Ready "node/${node}" --timeout="$((timeout - elapsed))s"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "ERROR: node ${node} did not register within ${timeout}s" >&2
  return 1
}

login_lab_registry() {
  log_section "Logging in to ${LAB_REGISTRY} on all Linux nodes"
  podman login -u "$LAB_REGISTRY_USER" -p "$LAB_REGISTRY_PASSWORD" "$LAB_REGISTRY"
  local host
  for host in "${WORKERS[@]}"; do
    remote "$host" "podman login -u '${LAB_REGISTRY_USER}' -p '${LAB_REGISTRY_PASSWORD}' '${LAB_REGISTRY}'"
  done
}

install_calico() {
  PHASE="Calico installation"
  log_section "Installing Calico ${CALICO_VERSION} without Windows support"
  login_lab_registry

  local work_dir="/root/addenda14-calico-${CALICO_VERSION}"
  mkdir -p "$work_dir"
  curl --fail --location --retry 3 \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml" \
    --output "${work_dir}/tigera-operator.yaml"

  # The Tigera CRDs exceed the 256KB limit of the client-side last-applied annotation.
  kubectl apply --server-side --force-conflicts -f "${work_dir}/tigera-operator.yaml"
  wait_for_crd_established installations.operator.tigera.io

  cat >"${work_dir}/custom-resources.yaml" <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  variant: Calico
  cni:
    type: Calico
    ipam:
      type: Calico
  calicoNetwork:
    bgp: Disabled
    hostPorts: Enabled
    linuxDataplane: Iptables
    multiInterfaceMode: None
    nodeAddressAutodetectionV4:
      firstFound: true
    ipPools:
    - blockSize: 26
      cidr: ${POD_SUBNET}
      disableBGPExport: false
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: all()
  controlPlaneReplicas: 2
  flexVolumePath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec/
  kubeletVolumePluginPath: /var/lib/kubelet
  serviceCIDRs:
  - ${SERVICE_SUBNET}
EOF

  kubectl apply -f "${work_dir}/custom-resources.yaml"
  kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=300s
  wait_for_node_ready "$CONTROL_PLANE"
}

join_workers() {
  PHASE="worker join"
  log_section "Joining Linux workers"

  local join_command host
  join_command=$(kubeadm token create --ttl 2h --print-join-command)
  for host in "${WORKERS[@]}"; do
    echo "Joining ${host}..."
    remote "$host" "${join_command} --cri-socket '${CRI_SOCKET}'"
    wait_for_node_ready "$host"
  done

  kubectl -n calico-system rollout status daemonset/calico-node --timeout=600s
  kubectl -n calico-system rollout status deployment/calico-kube-controllers --timeout=600s
}

install_metallb() {
  PHASE="MetalLB installation"
  log_section "Installing MetalLB ${METALLB_CHART_VERSION}"
  login_lab_registry

  local work_dir="/root/addenda14-metallb-${METALLB_CHART_VERSION}"
  mkdir -p "$work_dir"
  cat >"${work_dir}/values.yaml" <<'EOF'
controller:
  image:
    repository: registry.demo.netapp.com/metallb/controller
    tag: v0.14.5
  nodeSelector:
    kubernetes.io/os: linux
speaker:
  image:
    repository: registry.demo.netapp.com/metallb/speaker
    tag: v0.14.5
  nodeSelector:
    kubernetes.io/os: linux
  frr:
    enabled: false
prometheus:
  scrapeAnnotations: false
  rbacPrometheus: false
  podMonitor:
    enabled: false
  serviceMonitor:
    enabled: false
  prometheusRule:
    enabled: false
EOF

  helm repo add metallb https://metallb.github.io/metallb --force-update
  helm upgrade --install metallb metallb/metallb \
    --version "$METALLB_CHART_VERSION" \
    --namespace metallb-system \
    --create-namespace \
    --values "${work_dir}/values.yaml" \
    --wait \
    --timeout 10m

  cat >"${work_dir}/resources.yaml" <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${METALLB_POOL}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF

  kubectl apply -f "${work_dir}/resources.yaml"
  kubectl -n metallb-system rollout status deployment/metallb-controller --timeout=300s
  kubectl -n metallb-system rollout status daemonset/metallb-speaker --timeout=300s
}

verify_cluster() {
  PHASE="final verification"
  log_section "Verifying the rebuilt cluster"

  local actual_nodes expected_nodes
  actual_nodes=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)
  expected_nodes=$(printf '%s\n' "${EXPECTED_NODES[@]}" | sort)
  if [[ "$actual_nodes" != "$expected_nodes" ]]; then
    echo "ERROR: rebuilt node set is not the expected Linux-only set" >&2
    diff -u <(printf '%s\n' "$expected_nodes") <(printf '%s\n' "$actual_nodes") || true
    return 1
  fi

  local node version ready
  for node in "${EXPECTED_NODES[@]}"; do
    version=$(kubectl get node "$node" -o jsonpath='{.status.nodeInfo.kubeletVersion}')
    ready=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    [[ "$version" == "$TARGET_VERSION_V" ]]
    [[ "$ready" == "True" ]]
  done

  kubectl get nodes -o wide
  kubectl get pods -n tigera-operator
  kubectl get pods -n calico-system
  kubectl get pods -n metallb-system
  kubectl -n metallb-system get ipaddresspool,l2advertisement

  echo
  echo "Cluster rebuild completed successfully."
  if [[ -n "$BACKUP_DIR" ]]; then
    echo "Configuration backup: ${BACKUP_DIR}"
  fi
  echo "Windows hosts win1/win2 were not modified and were not rejoined."
  echo "Trident, KubeVirt, applications, and other previous workloads were not reinstalled."
}

resume_rebuild() {
  log_section "Resuming the rebuild from phase '${RESUME_FROM}'"
  echo "No node is reset; only the remaining installation phases run."

  case "$RESUME_FROM" in
    calico)
      install_calico
      join_workers
      install_metallb
      ;;
    join)
      join_workers
      install_metallb
      ;;
    metallb)
      install_metallb
      ;;
  esac

  verify_cluster
}

main() {
  parse_arguments "$@"
  preflight

  if [[ -n "$RESUME_FROM" ]]; then
    resume_rebuild
    exit 0
  fi

  backup_configuration

  if [[ "$BACKUP_ONLY" == true ]]; then
    echo "Backup-only mode complete; no cluster changes were made."
    exit 0
  fi

  confirm_destruction

  # Package availability is checked before destroying the working API server.
  verify_target_packages

  PHASE="Linux worker reset"
  local host
  for host in "${WORKERS[@]}"; do
    reset_remote_node "$host"
  done

  # This is only for a clear audit trail; the API disappears in the next step.
  kubectl delete node win1 win2 --ignore-not-found
  reset_control_plane
  initialize_control_plane
  install_calico
  join_workers
  install_metallb
  verify_cluster
}

main "$@"
