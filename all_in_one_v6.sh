#!/bin/bash

# ------------------------------------------------------------------------------------------
# K8S1_trident_upgrade()
#
# FUNCTION THAT WILL PERFORM THE FOLLOWING TASKS:
# 1. UPGRADE HELM
# 2. UPGRADE TRIDENT OPERATOR TO 25.10.0 WITH HELM
# 3. CONFIGURE FILE (NFS/SMB) BACKENDS FOR TRIDENT
# 4. CONFIGURE BLOCK (iSCSI/NVME) BACKENDS FOR TRIDENT
# 5. MONITORING CUSTOMIZATION & HARVEST
# 6. ENABLE POD SCHEDULING ON THE CONTROL PLANE"
# 7. ADD TOOLS
# 8. INSTALL KUBEVIRT
# ------------------------------------------------------------------------------------------


K8S1_trident_upgrade() {

echo
echo "#######################################################################################################"
echo "# 1. UPGRADE HELM"
echo "#######################################################################################################"
echo

wget https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz
tar -xvf helm-v3.15.3-linux-amd64.tar.gz
/bin/cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v3.15.3-linux-amd64.tar.gz

echo
echo "#######################################################################################################"
echo "# 2. UPGRADE TRIDENT OPERATOR TO 25.10.0 WITH HELM"
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
echo "# 5. MONITORING CUSTOMIZATION & HARVEST"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "# 6. ENABLE POD SCHEDULING ON THE CONTROL PLANE"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule-

echo
echo "#######################################################################################################"
echo "# 7. ADD TOOLS"
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
echo "# 8. INSTALL KUBEVIRT"
echo "#######################################################################################################"
echo
sh ~/LabNetApp/Kubernetes_v6/Addendum/Addenda15/all_in_one_rhel3.sh

}






# ------------------------------------------------------------------------------------------
# lab_setup_trident_protect()
#
# Function that will perform the following tasks:
# 1. UPGRADE TRIDENT TO 25.10.0 ON KUBERNETES#1
# 2. CREATE A SECONDARY SVM
# 3. CONFIGURE SVM PEERING
# 4. CREATE A S3 SVM (TARGET FOR BACKUPS)
# 5. CREATE & CONFIGURE A SECONDARY KUBERNETES CLUSTER
# 6. INSTALL TRIDENT PROTECT 25.10.0 ON KUBERNETES#1
# 7. INSTALL TRIDENT & TRIDENT PROTECT 25.10.0 ON KUBERNETES#2
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

# Upgrade Trident to 25.10.0 if needed
if [ $(kubectl get tver trident -n trident -o jsonpath={".trident_version"}) != "25.10.0" ]; then K8S1_trident_upgrade; fi

# Secondary SVM Creation + Peering
# S3 SVM & Bucket Creation
# Secondary K8S cluster Creation
# Install Trident on KS8#2
# Install a VSCass on K8S#1
# Git Clone Verda on RHEL3
bash ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario01/all_in_one.sh

# Trident Protect on K8S#1
cd ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario02
bash all_in_one_rhel3.sh

# Trident Protect on K8S#2
scp -p ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario02/all_in_one_rhel5.sh rhel5:all_in_one_tp_setup.sh
ssh -o "StrictHostKeyChecking no" root@rhel5 -t "bash all_in_one_tp_setup.sh"

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
#
# Main Menu
#
# ------------------------------------------------------------------------------------------

read -n 1 -p "Which task would you like to perform?
1. Upgrade Trident, Configure Monitoring & install KubeVirt
2. Setup the lab for Trident Protect 
0. Exit the script
" ans;

echo
case $ans in
    0)
        exit;;
    1)
        K8S1_trident_upgrade;;
    2)
        lab_setup_trident_protect;;
    *)
        echo "Please restart the script with a valid option (0|1|2)";;
esac


if [ $(more ~/.bashrc | grep kdesc | wc -l) -ne 1 ]; then
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
fi

echo
echo "#######################################################################################################"
echo "# CHECK DOCKER HUB PULL TOKEN"
echo "#######################################################################################################"
echo

TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

echo "# Your anonymous login to the Docker Hub currently has $RATEREMAINING pulls left."

echo
echo "#######################################################################################################"
echo "# SETUP CHECKS"
echo "#######################################################################################################"
echo
print_ok() { printf "\e[32m✓\e[0m %s\n" "$1"; }
print_fail() { printf "\e[31m✗\e[0m %s\n" "$1"; }

_kc_arg() {
  [ -n "$1" ] && printf '%s' "--kubeconfig=$1"
}

check_pods_running() {
  local kubeconfig=$1; local ns=$2; local title=$3
  local kc; kc=$(_kc_arg "$kubeconfig")
  local notok
  if ! kubectl $kc -n "$ns" get pods --no-headers >/dev/null 2>&1; then
    print_fail "$title: namespace/$ns not found or cluster unreachable"
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
      if echo "$phase" | grep -iq "avail"; then
        print_ok "$title: AppVault '$name' status='$phase'"
        return 0
      else
        print_fail "$title: AppVault '$name' status='$phase'"
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

echo "Checking primary cluster (default kubeconfig)..."
check_pods_running "" trident "Primary: trident namespace"
check_tbc_status ""
check_pods_running "" kubevirt "Primary: kubevirt namespace"
check_pods_running "" cdi "Primary: cdi namespace"
check_pods_running "" kubevirt-manager "Primary: kubevirt-manager namespace"
if [ "$ans" = "2" ]; then
  check_pods_running "" trident-protect "Primary: trident-protect namespace"
  check_appvault_available "" "ontap-vault" "Primary: AppVault"

echo
local SECONDARY_KUBECONFIG="/root/.kube/config_rhel5"
echo "Checking secondary cluster (kubeconfig=$SECONDARY_KUBECONFIG)..."
check_pods_running "$SECONDARY_KUBECONFIG" trident "Secondary: trident namespace"
check_tbc_status "$SECONDARY_KUBECONFIG"
check_pods_running "$SECONDARY_KUBECONFIG" kubevirt "Secondary: kubevirt namespace"
check_pods_running "$SECONDARY_KUBECONFIG" cdi "Secondary: cdi namespace"
check_pods_running "$SECONDARY_KUBECONFIG" kubevirt-manager "Secondary: kubevirt-manager namespace"
check_pods_running "$SECONDARY_KUBECONFIG" trident-protect "Secondary: trident-protect namespace"
check_appvault_available "$SECONDARY_KUBECONFIG" "ontap-vault" "Secondary: AppVault"
fi

echo
echo "-----------------------"
echo "____ HAVE FUN !!!!!"
echo "-----------------------"
echo