#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

echo
echo "#######################################################################################################"
echo "#"
echo "# ALL IN ONE SCRIPT THAT PERFORMS THE FOLLOWING TASKS:"
echo "#"
echo "# 0. DEALING WITH THE DOCKER HUB & THE RATE ON PULL IMAGES"
echo "# 1. UPGRADE HELM"
echo "# 2. UPGRADE TRIDENT OPERATOR TO 24.06.1 WITH HELM"
echo "# 3. CONFIGURE FILE (NFS/SMB) BACKENDS FOR TRIDENT"
echo "# 4. CONFIGURE BLOCK (iSCSI/NVME) BACKENDS FOR TRIDENT"
echo "# 5. MONITORING CUSTOMIZATION & HARVEST"
echo "# 6. ENABLE POD SCHEDULING ON THE CONTROL PLANE" 
echo "# 7. ADD TOOLS"
echo "# 8. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

echo
echo "#######################################################################################################"
echo "#"
echo "# 0. DEALING WITH THE DOCKER HUB & THE RATE ON PULL IMAGES"
echo "#"
echo "#######################################################################################################"
echo

if [[ $# -ne 2 ]];then
  TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
  RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

  if [[ $RATEREMAINING -eq 0 ]];then
      echo "----------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have any pull request left. Consider using your own credentials."
      echo "----------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0

  elif [[ $RATEREMAINING -lt 20 ]];then
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have many pull requests left ($RATEREMAINING). Consider using your own credentials"
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
  else
      echo "--------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub seems to have plenty of pull requests left ($RATEREMAINING)."
      echo "--------------------------------------------------------------------------------------------"
  fi
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# 1. UPGRADE HELM"
echo "#"
echo "#######################################################################################################"
echo

wget https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz
tar -xvf helm-v3.15.3-linux-amd64.tar.gz
cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v3.15.3-linux-amd64.tar.gz

echo
echo "#######################################################################################################"
echo "#"
echo "# 2. UPGRADE TRIDENT OPERATOR TO 24.06.1 WITH HELM"
echo "#"
echo "#######################################################################################################"
echo

cd ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario01/1_Helm
if [[ $# -eq 2 ]];then
  sh all_in_one.sh $1 $2
else
  sh all_in_one.sh
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# 3. CONFIGURE FILE (NFS/SMB) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario02/all_in_one.sh 

echo
echo "#######################################################################################################"
echo "#"
echo "# 4. CONFIGURE BLOCK (iSCSI/NVME) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario05/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 5. MONITORING CUSTOMIZATION & HARVEST"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 6. ENABLE POD SCHEDULING ON THE CONTROL PLANE"
echo "#"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule-

echo
echo "#######################################################################################################"
echo "#"
echo "# 7. ADD TOOLS"
echo "#"
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
kubectl krew install view-utilization
kubectl krew install tree
kubectl krew install view-secret

echo
echo "#######################################################################################################"
echo "#"
echo "# 8. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

cp ~/.bashrc ~/.bashrc.bak
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
source ~/.bashrc