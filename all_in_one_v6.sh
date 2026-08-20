#!/bin/bash

# ------------------------------------------------------------------------------------------
# K8S1_trident_upgrade()
#
# FUNCTION THAT WILL PERFORM THE FOLLOWING TASKS:
# 1. UPGRADE HELM
# 2. INSTALL TRIDENT OPERATOR TO 26.06.0 WITH HELM
# 3. CONFIGURE FILE (NFS/SMB) BACKENDS FOR TRIDENT
# 4. CONFIGURE BLOCK (iSCSI/NVME) BACKENDS FOR TRIDENT
# 5. INSTALL VOLUME SNAPSHOT CONTROLLER 8.2 & CREATE A VOLUMESNAPSHOTCLASS FOR TRIDENT
# 6. MONITORING CUSTOMIZATION & HARVEST
# 7. ENABLE POD SCHEDULING ON THE CONTROL PLANE"
# 8. ADD TOOLS
# 9. INSTALL KUBEVIRT
# ------------------------------------------------------------------------------------------


K8S1_trident_upgrade() {

echo
echo "#######################################################################################################"
echo "# 1. UPGRADE HELM"
echo "#######################################################################################################"
echo

wget https://get.helm.sh/helm-v4.0.5-linux-amd64.tar.gz
tar -xvf helm-v4.0.5-linux-amd64.tar.gz
/bin/cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v4.0.5-linux-amd64.tar.gz

echo
echo "#######################################################################################################"
echo "# 2. INSTALL TRIDENT OPERATOR TO 26.06.0 WITH HELM"
echo "#######################################################################################################"
echo

sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario01/1_Helm/all_in_one.sh

echo
echo "#######################################################################################################"
echo "# 3. CONFIGURE FILE (NFS/SMB) BACKENDS FOR TRIDENT"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario02/all_in_one.sh 

echo
echo "#######################################################################################################"
echo "# 4. CONFIGURE BLOCK (iSCSI/NVME) BACKENDS FOR TRIDENT"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario05/all_in_one.sh

echo
echo "#######################################################################################################"
echo "# 5. INSTALL VOLUME SNAPSHOT CONTROLLER 8.2 & CREATE A VOLUMESNAPSHOTCLASS FOR TRIDENT"
echo "#######################################################################################################"
echo

  sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario13/vscontroller_install_8.sh

echo
echo "#######################################################################################################"
echo "# 6. MONITORING CUSTOMIZATION & HARVEST"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "# 7. ENABLE POD SCHEDULING ON THE CONTROL PLANE"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule-

echo
echo "#######################################################################################################"
echo "# 8. ADD TOOLS"
echo "#######################################################################################################"
echo

(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

kubectl krew install get-all
kubectl krew install stern
kubectl krew install view-utilization
kubectl krew install tree
kubectl krew install view-secret
kubectl krew install view-serviceaccount-kubeconfig

echo
echo "#######################################################################################################"
echo "# 9. INSTALL KUBEVIRT"
echo "#######################################################################################################"
echo
sh ~/LabNetApp/Kubernetes_v6/Addendum/Addenda15/all_in_one_rhel3.sh

}






# ------------------------------------------------------------------------------------------
# lab_setup_trident_protect()
#
# Function that will perform the following tasks:
# 1. UPGRADE TRIDENT TO 26.06.0 ON KUBERNETES#1
# 2. CREATE A SECONDARY SVM
# 3. CONFIGURE SVM PEERING
# 4. CREATE A S3 SVM (TARGET FOR BACKUPS)
# 5. CREATE & CONFIGURE A SECONDARY KUBERNETES CLUSTER
# 6. INSTALL TRIDENT PROTECT 26.06.0 ON KUBERNETES#1
# 7. INSTALL TRIDENT & TRIDENT PROTECT 26.06.0 ON KUBERNETES#2
# 8. CREATE AN APPVAULT ON BOTH CLUSTERS
# 9. CONFIGURE KUBE STATE METRICS TO MONITOR TRIDENT PROTECT
# 10. INSTALL KUBEVIRT ON KUBERNETES#2
# ------------------------------------------------------------------------------------------


lab_setup_trident_protect() {

ping -c1 -W1 -q rhel4 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL4 from the LoD MyLabs page."
  echo "# Once the host is up&running, restart this script."
  echo "#################################################################"
  exit 0
fi
ping -c1 -W1 -q rhel5 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL5 from the LoD MyLabs page"
  echo "# Once the host is up&running, restart this script."
  echo "#################################################################"
  exit 0
fi

# Upgrade Trident to 26.06.0 if needed
if [ $(kubectl get tver trident -n trident -o jsonpath={".trident_version"}) != "26.06.0" ]; then K8S1_trident_upgrade; fi

# Secondary SVM Creation + Peering
# S3 SVM & Bucket Creation
# Secondary K8S cluster Creation
# Install Trident on KS8#2
# Install a VSClass on K8S#1
# Git Clone Verda on RHEL3
bash ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario01/all_in_one.sh

# Trident Protect on K8S#1
cd ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario02
bash all_in_one_rhel3.sh

# Trident Protect on K8S#2
bash all_in_one_rhel5.sh

echo
echo "############################################"
echo "### AppVault Creation on RHEL3"
echo "############################################"
BUCKETKEY=$(grep "access_key" /root/ansible_S3_SVM_result.txt | cut -d ":" -f 2 | cut -b 2- | sed 's/..$//') && echo $BUCKETKEY
BUCKETSECRET=$(grep "secret_key" /root/ansible_S3_SVM_result.txt | cut -d ":" -f 2 | cut -b 2- | sed 's/..$//') && echo $BUCKETSECRET

kubectl create secret generic -n trident-protect s3-creds \
  --from-literal=accessKeyID=$BUCKETKEY \
  --from-literal=secretAccessKey=$BUCKETSECRET
  
tridentctl-protect create appvault OntapS3 ontap-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect

echo
echo "############################################"
echo "### AppVault Creation on RHEL5"
echo "############################################"

kubectl --kubeconfig=/root/.kube/config_rhel5 create secret generic -n trident-protect s3-creds \
  --from-literal=accessKeyID=$BUCKETKEY \
  --from-literal=secretAccessKey=$BUCKETSECRET

tridentctl-protect create appvault OntapS3 ontap-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect --context kub2-admin@kub2

echo
echo "############################################"
echo "### AWS S3 Tool install & configure"
echo "############################################"
cd
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws

mkdir ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $BUCKETKEY
aws_secret_access_key = $BUCKETSECRET
EOF

echo
echo "############################################"
echo "### Kube State Metrics"
echo "############################################"
# Kube State Metrics
cd ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario04
sh all_in_one.sh

echo
echo "############################################"
echo "### Install KubeVirt on RHEL5"
echo "############################################"
curl -s --insecure --user root:Netapp1! -T ~/LabNetApp/Kubernetes_v6/Addendum/Addenda15/all_in_one_rhel5.sh sftp://rhel5/root/kv_setup.sh
ssh -o "StrictHostKeyChecking no" root@rhel5 -t "sh kv_setup.sh"

}



# ------------------------------------------------------------------------------------------
# lab_setup_check()
#
# Functions:
# check_pods_running
# check_appvault_available
# check_tbc_status
# check_trident_version
# check_tridentctl_protect  
# ------------------------------------------------------------------------------------------


print_ok() { printf "\e[32m✓\e[0m %s\n" "$1"; }
print_fail() { printf "\e[31m✗\e[0m %s\n" "$1"; }

_kc_arg() {
  [ -n "$1" ] && printf '%s' "--kubeconfig=$1"
}

check_pods_running() {
  local kubeconfig=$1; local ns=$2; local title=$3
  local kc; kc=$(_kc_arg "$kubeconfig")
  local notok
  if ! kubectl $kc get ns "$ns" >/dev/null 2>&1; then
    print_fail "$title: namespace/$ns not found"
    return 1
  fi
  if ! kubectl $kc -n "$ns" get pods --no-headers >/dev/null 2>&1; then
    print_fail "$title: cluster unreachable while checking namespace/$ns"
    return 1
  fi
  # find pods whose STATUS is not Running or Completed
  notok=$(kubectl $kc -n "$ns" get pods --no-headers 2>/dev/null | awk '$3!="Running" {print $0}')
  if [ -z "$notok" ]; then
    print_ok "$title: all pods Running in namespace '$ns'"
    return 0
  else
    print_fail "$title: some pods NOT Running in namespace '$ns':"
    printf "%s\n" "$notok"
    return 2
  fi
}

check_appvault_available() {
  local kubeconfig=$1; local name=$2; local title=$3
  local kc; kc=$(_kc_arg "$kubeconfig")
  # verify namespace exists
  if ! kubectl $kc -n trident-protect get appvault >/dev/null 2>&1; then
    print_fail "$title: no AppVault resources found or trident-protect namespace unreachable"
    return 1
  fi
  if [ -n "$name" ]; then
    # check specific appvault
    local state
    state=$(kubectl $kc -n trident-protect get appvault "$name" -o jsonpath='{.status.state}' 2>/dev/null || true)
    if [ -z "$state" ]; then
      # existence check
      if kubectl $kc -n trident-protect get appvault "$name" >/dev/null 2>&1; then
        print_ok "$title: AppVault '$name' exists (no state reported)"
        return 0
      else
        print_fail "$title: AppVault '$name' NOT found"
        return 2
      fi
    else
      if echo "$state" | grep -iq "avail"; then
        print_ok "$title: AppVault '$name' status='$state'"
        return 0
      else
        print_fail "$title: AppVault '$name' status='$state'"
        return 3
      fi
    fi
  else
    # check any appvault with Available phase
    local states
    states=$(kubectl $kc -n trident-protect get appvault -o jsonpath='{range .items[*]}{.metadata.name}: {.status.state}  ' 2>/dev/null || true)
    if echo "$states" | grep -iq "avail"; then
      print_ok "$title: at least one AppVault is Available"
      return 0
    else
      print_fail "$title: no AppVault in Available state; found: $states"
      return 4
    fi
  fi
}

check_tbc_status() {
  local kubeconfig=${1:-}
  local kc; kc=$(_kc_arg "$kubeconfig")

  if ! kubectl $kc -n trident get tridentbackendconfig >/dev/null 2>&1; then
    print_fail "TBC check: no TridentBackendConfig resources found or 'trident' namespace unreachable"
    return 1
  fi

  local lines total bound success both
  lines=$(kubectl $kc -n trident get tridentbackendconfig -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase} {.status.lastOperationStatus}{"\n"}{end}' 2>/dev/null || true)
  total=$(printf "%s" "$lines" | awk 'NF{count++}END{print count+0}')
  if [ "$total" -eq 0 ]; then
    print_fail "TBC check: no TridentBackendConfig objects found"
    return 2
  fi

  bound=$(printf "%s" "$lines" | awk '{if(tolower($2)=="bound") c++}END{print c+0}')
  success=$(printf "%s" "$lines" | awk '{if(tolower($3)=="success") c++}END{print c+0}')
  both=$(printf "%s" "$lines" | awk '{if(tolower($2)=="bound" && tolower($3)=="success") c++}END{print c+0}')

  if [ "$both" -eq "$total" ]; then
    print_ok "TridentBackendConfig: $both/$total are phase=Bound and status=Success"
  else
    print_fail "TridentBackendConfig: $both/$total are phase=Bound and status=Success"
  fi
  return 0
}

check_trident_version() {
  local kubeconfig=$1; local version=$2
  local kc; kc=$(_kc_arg "$kubeconfig")
  local value
  value=$(kubectl $kc get tver trident -n trident -o jsonpath='{.trident_version}' 2>/dev/null || true)
  if [ "$value" = "$version" ]; then
    print_ok "Trident: version is $value"
  else
    print_fail "Trident: version is $value"
  fi
}

check_tridentctl_protect() {
  local cluster=$1
  local packsize

  if [[ "$cluster" == "cluster1" ]]; then
    packsize=$(du --apparent-size --block-size=1 /usr/local/bin/tridentctl-protect 2>/dev/null | awk '{ print $1 }')
  else
    packsize=$(ssh -o "StrictHostKeyChecking no" root@rhel5 "du --apparent-size --block-size=1 /usr/local/bin/tridentctl-protect 2>/dev/null | awk '{ print \$1 }'" | tr -d '\r')
  fi

  if [[ -z "$packsize" ]] || [[ "$packsize" -lt 10000 ]]; then
    print_fail "Tridentctl Protect: binary missing or size too small (size=${packsize:-0} bytes)"
  else
    print_ok "Tridentctl Protect: binary OK (size=${packsize} bytes)"
  fi
}

check_volume_snapshot_controller() {
  local kubeconfig=$1; local version=$2
  local kc; kc=$(_kc_arg "$kubeconfig")

  local rc=0
  local image image_no_digest tag major expected_major vsc_count

  # Check snapshot-controller deployment presence
  if ! kubectl $kc -n kube-system get deploy snapshot-controller >/dev/null 2>&1; then
    print_fail "Volume Snapshot Controller: deployment 'snapshot-controller' not found in namespace 'kube-system'"
    return 1
  fi

  # Read controller image and compare only major version against expected version
  image=$(kubectl $kc -n kube-system get deploy snapshot-controller -ojsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  if [ -z "$image" ]; then
    print_fail "Volume Snapshot Controller: unable to read controller image"
    rc=1
  else
    image_no_digest=${image%@*}
    if [ "$image_no_digest" = "$image" ] && [[ "$image" != *:* ]]; then
      tag=""
    else
      tag=${image_no_digest##*:}
    fi

    major=$(printf "%s" "$tag" | sed -E 's/^v//; s/^([0-9]+).*/\1/')
    expected_major=$(printf "%s" "$version" | sed -E 's/^v//; s/^([0-9]+).*/\1/')

    if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$expected_major" =~ ^[0-9]+$ ]]; then
      if [ "$major" = "$expected_major" ]; then
        print_ok "Volume Snapshot Controller:  tag=$tag matches expected major version=$expected_major"
      else
        print_fail "Volume Snapshot Controller: tag=$tag does not match expected major version=$expected_major"
        rc=1
      fi
    else
      print_fail "Volume Snapshot Controller: could not parse major version from image tag '$tag'"
      rc=1
    fi
  fi

  # Check that at least one VolumeSnapshotClass exists
  if ! kubectl $kc get volumesnapshotclass >/dev/null 2>&1; then
    print_fail "VolumeSnapshotClass: resource not found or cluster unreachable"
    rc=1
  else
    vsc_count=$(kubectl $kc get volumesnapshotclass --no-headers 2>/dev/null | awk 'NF{c++}END{print c+0}')
    if [ "$vsc_count" -gt 0 ]; then
      print_ok "Volume Snapshot Class: found $vsc_count class(es)"
    else
      print_fail "Volume Snapshot Class: no class found"
      rc=1
    fi
  fi

  return "$rc"
}

compare_registry_images() {
  local trident_version=$1
  local autosupport_version=$2
  local protect_version=$3
  local menu=$4
  local all_ok=1
  local failed_images=()
  
  # Always test these images
  local base_images=("trident" "trident-operator" "trident-autosupport")
  
  # Multi-arch images: digest comparison is unreliable due to manifest list normalization
  local multiarch_images=("trident" "trident-operator" "trident-autosupport")
  
  # Add Trident Protect images if menu = 2
  local protect_images=()
  if [ "$menu" = "2" ]; then
    protect_images=("controller" "exechook" "resourcebackup" "resourcerestore" "resourcedelete" "restic" "kopia" "kopiablockrestore")
  fi
  
  local all_images=("${base_images[@]}" "${protect_images[@]}")
  
  echo
  echo "#######################################################################################################"
  echo "# COMPARE REGISTRY IMAGE DIGESTS (docker.io vs quay.io)"
  echo "#######################################################################################################"
  echo
  
  for image in "${all_images[@]}"; do
    local digest1 digest2
    local tag="$trident_version"
    
    # trident-autosupport follows its own release schedule
    if [ "$image" = "trident-autosupport" ]; then
      tag="$autosupport_version"
    fi
    
    # Trident Protect images follow their own release schedule
    if [[ " ${protect_images[@]} " =~ " ${image} " ]]; then
      tag="$protect_version"
    fi
    
    # For trident-protect-utils when menu=2, use v1.0.0 instead of the version
    if [ "$image" = "trident-protect-utils" ] && [ "$menu" = "2" ]; then
      tag="v1.0.0"
    fi
    
    # Special handling for trident-protect-utils in base menu
    if [ "$image" = "trident-protect-utils" ]; then
      continue
    fi
    
      # For multi-arch images, compare linux/amd64 arch digest specifically
      if [[ " ${multiarch_images[@]} " =~ " ${image} " ]]; then
        # Get Docker Hub token scoped to this specific image
        local docker_token
        docker_token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:netapp/$image:pull" 2>/dev/null | jq -r '.token' || true)
        
        # Fetch manifest list from docker.io with authentication
        local manifest_list1
        manifest_list1=$(curl -s -H "Authorization: Bearer $docker_token" \
          -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
          "https://registry-1.docker.io/v2/netapp/$image/manifests/$tag" 2>/dev/null)
        
        # Prefer an OCI or Docker image index; Quay can otherwise return a legacy schema-v1 manifest.
        local manifest_list2
        manifest_list2=$(curl -s -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
          "https://quay.io/v2/yvosonthehub/netapp/$image/manifests/$tag" 2>/dev/null)
        
        # Extract linux/amd64 digest from docker.io manifest list
        digest1=$(echo "$manifest_list1" | jq -r '[.manifests[]? | select(.platform.os == "linux" and .platform.architecture == "amd64") | .digest][0] // empty' 2>/dev/null || true)
        
        # Extract linux/amd64 digest from quay.io manifest list
        digest2=$(echo "$manifest_list2" | jq -r '[.manifests[]? | select(.platform.os == "linux" and .platform.architecture == "amd64") | .digest][0] // empty' 2>/dev/null || true)
        
        if [ -z "$digest1" ]; then
          print_fail "Image comparison: docker.io did not return a linux/amd64 manifest for $image:$tag"
          all_ok=0
          failed_images+=("$image")
        elif [ -z "$digest2" ]; then
          print_fail "Image comparison: quay.io did not return an OCI or Docker manifest index for $image:$tag"
          all_ok=0
          failed_images+=("$image")
        elif [ "$digest1" = "$digest2" ]; then
          print_ok "Image match: $image:$tag linux/amd64 (digest: ${digest1:0:19}...)"
        else
          print_fail "the mirror image $image does not correspond to the source repo (docker.io: ${digest1:0:19}... vs quay.io: ${digest2:0:19}...)"
          all_ok=0
          failed_images+=("$image")
        fi
    else
      # For single-arch images, compare digests
      # Get Docker Hub token scoped to this specific image
      local docker_token
      docker_token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:netapp/$image:pull" 2>/dev/null | jq -r '.token' || true)
      
      # Get manifest digest from docker.io/netapp using Docker Registry V2 API with authentication
      # Use HEAD request to get Docker-Content-Digest header without downloading full manifest
      digest1=$(curl -s -I -H "Authorization: Bearer $docker_token" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json" \
        "https://registry-1.docker.io/v2/netapp/$image/manifests/$tag" 2>/dev/null | \
        grep -i docker-content-digest | cut -d ' ' -f 2 | tr -d '\r' || true)
      
      # Get manifest digest from quay.io/yvosonthehub/netapp (public, no auth needed)
      digest2=$(curl -s -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json" \
        "https://quay.io/v2/yvosonthehub/netapp/$image/manifests/$tag" 2>/dev/null | \
        grep -i docker-content-digest | cut -d ' ' -f 2 | tr -d '\r' || true)
      
      if [ -z "$digest1" ] || [ -z "$digest2" ]; then
        print_fail "Image comparison: could not retrieve digest for $image:$tag"
        all_ok=0
        failed_images+=("$image")
      elif [ "$digest1" = "$digest2" ]; then
        print_ok "Image match: $image:$tag (digest: ${digest1:0:19}...)"
      else
        print_fail "the mirror image $image does not correspond to the source repo (docker.io: ${digest1:0:19}... vs quay.io: ${digest2:0:19}...)"
        all_ok=0
        failed_images+=("$image")
      fi
    fi
  done
  
  # Handle trident-protect-utils specially when menu=2
  if [ "$menu" = "2" ]; then
    local image="trident-protect-utils"
    local tag="v1.0.0"
    local digest1 digest2
    
    # Get Docker Hub token scoped to this specific image
    local docker_token
    docker_token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:netapp/$image:pull" 2>/dev/null | jq -r '.token' || true)
    
    digest1=$(curl -s -I -H "Authorization: Bearer $docker_token" \
      -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json" \
      "https://registry-1.docker.io/v2/netapp/$image/manifests/$tag" 2>/dev/null | \
      grep -i docker-content-digest | cut -d ' ' -f 2 | tr -d '\r' || true)
    
    digest2=$(curl -s -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.docker.distribution.manifest.list.v2+json" \
      "https://quay.io/v2/yvosonthehub/netapp/$image/manifests/$tag" 2>/dev/null | \
      grep -i docker-content-digest | cut -d ' ' -f 2 | tr -d '\r' || true)
    
    if [ -z "$digest1" ] || [ -z "$digest2" ]; then
      print_fail "Image comparison: could not retrieve digest for $image:$tag"
      all_ok=0
      failed_images+=("$image")
    elif [ "$digest1" = "$digest2" ]; then
      print_ok "Image match: $image:$tag (digest: ${digest1:0:19}...)"
    else
      print_fail "the mirror image $image does not correspond to the source repo"
      all_ok=0
      failed_images+=("$image")
    fi
  fi
  
  echo
  if [ $all_ok -eq 1 ]; then
    print_ok "all mirror images conformant with the source repo"
  fi
}

lab_setup_check() {
  local menu=$1
  echo
  echo "#######################################################################################################"
  echo "# SETUP CHECKS"
  echo "#######################################################################################################"
  echo

  echo "Checking primary cluster (default kubeconfig)..."
  check_pods_running "" trident "Trident"
  check_trident_version "" "26.06.1"
  check_tbc_status ""
  check_volume_snapshot_controller "" "8"
  check_pods_running "" kubevirt "KubeVirt"
  check_pods_running "" cdi "CDI"
  check_pods_running "" kubevirt-manager "KubeVirt Manager"
  if [ "$menu" = "2" ]; then
    check_pods_running "" trident-protect "Trident Protect"
    check_tridentctl_protect "cluster1"
    check_appvault_available "" "ontap-vault" "AppVault"

  echo
  SECONDARY_KUBECONFIG="/root/.kube/config_rhel5"
  echo "Checking secondary cluster (kubeconfig=$SECONDARY_KUBECONFIG)..."
  check_pods_running "$SECONDARY_KUBECONFIG" trident "Trident"
  check_trident_version "$SECONDARY_KUBECONFIG" "26.06.1"
  check_tbc_status "$SECONDARY_KUBECONFIG"
  check_volume_snapshot_controller "$SECONDARY_KUBECONFIG" "8"
  check_pods_running "$SECONDARY_KUBECONFIG" kubevirt "KubeVirt"
  check_pods_running "$SECONDARY_KUBECONFIG" cdi "CDI"
  check_pods_running "$SECONDARY_KUBECONFIG" kubevirt-manager "KubeVirt Manager"
  check_pods_running "$SECONDARY_KUBECONFIG" trident-protect "Trident Protect"
  check_tridentctl_protect "cluster2"
  check_appvault_available "$SECONDARY_KUBECONFIG" "ontap-vault" "AppVault"
  fi

  # Compare registry images between docker.io and quay.io
  compare_registry_images "26.06.1" "26.06.0" "26.06.0" "$menu"

if [ $(more ~/.bashrc | grep kdesc | wc -l) -ne 1 ]; then
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias kl='kubectl logs'
alias trident='tridentctl -n trident'
EOT
fi

  echo
  echo "#######################################################################################################"
  echo "# CHECK DOCKER HUB PULL TOKEN"
  echo "#######################################################################################################"
  echo

  TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
  RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i '^ratelimit-remaining:' | cut -d ':' -f 2 | cut -d ';' -f 1 | xargs)

  echo "# Your anonymous login to the Docker Hub currently has $RATEREMAINING pulls left."
}







# ------------------------------------------------------------------------------------------
#
# Main Menu
#
# ------------------------------------------------------------------------------------------

read -n 1 -p "Which task would you like to perform?
1. Upgrade Trident, Configure Monitoring & install KubeVirt
2. Setup the lab for Trident Protect
3. Check Setup
0. Exit the script
" ans;

echo
setup_start=""
selected_task=""

case $ans in
    0)
        exit
        ;;
    1)
        setup_start=$(date +%s)
        selected_task="1"
        K8S1_trident_upgrade
        lab_setup_check "1"
        ;;
    2)
        setup_start=$(date +%s)
        selected_task="2"
        lab_setup_trident_protect
        lab_setup_check "2"
        ;;
    3)
        if [[ -f /root/.kube/config_rhel5 ]]; then
          lab_setup_check "2"
        else
          lab_setup_check "1"
        fi
        ;;
    *)
        echo "Please restart the script with a valid option (0|1|2|3)"
        ;;
esac


if [[ -n "$setup_start" ]]; then
    setup_end=$(date +%s)
    elapsed=$((setup_end - setup_start))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))

    echo "Task $selected_task completed in ${minutes}m ${seconds}s (${elapsed}s)."
fi

echo
echo "-----------------------"
echo "____ HAVE FUN !!!!!"
echo "-----------------------"
echo