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
echo "# 2. CLEAN UP THE CURRENT ENVIRONMENT & PUSH TRIDENT IMAGES TO PRIVATE REPO"
echo "# 3. INSTALL TRIDENT OPERATOR 21.07.2 WITH HELM"
echo "# 4. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "# 5. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "# 6. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "# 7. INSTALL & CONFIGURE HARVEST"
echo "# 8. ENABLE POD SCHEDULING ON THE MASTER NODE" 
echo "# 9. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

if [[ $(yum info jq -y | grep Repo | awk '{ print $3 }') != "installed" ]]
  then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi

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

else
  sleep 2s
  echo
  echo "#######################################################################################################"
  echo "#"
  echo "# 0. LOGIN TO DOCKER HUB & PULL IMAGES REQUIRED FOR THIS SETUP"
  echo "#"
  echo "#######################################################################################################"
  echo

  cd ~/LabNetApp/Kubernetes_v4
  sh Addendum/Addenda08/2_Lazy_Images/pull_setup_images.sh rhel1 $1 $2
  sh Addendum/Addenda08/2_Lazy_Images/pull_setup_images.sh rhel2 $1 $2
  sh Addendum/Addenda08/2_Lazy_Images/pull_setup_images.sh rhel3 $1 $2
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# 1. UPGRADE HELM"
echo "#"
echo "#######################################################################################################"
echo

cd ~/helm
rm -rf linux-amd64
wget https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz
tar -zxvf helm-v3.6.3-linux-amd64.tar.gz
mv -f linux-amd64/helm /usr/bin/helm
helm repo add "stable" "https://charts.helm.sh/stable" --force-update

echo
echo "#######################################################################################################"
echo "#"
echo "# 2. CLEAN UP THE CURRENT ENVIRONMENT & PUSH TRIDENT IMAGES TO PRIVATE REPO"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
cd ~/LabNetApp/Kubernetes_v4
sh Scenarios/Scenario01/2_Helm/trident_uninstall.sh
sh Addendum/Addenda08/4_Private_repo/push_trident_images_to_repo.sh rhel3 $1 $2

echo
echo "#######################################################################################################"
echo "#"
echo "# 3. INSTALL TRIDENT OPERATOR 21.07.2 WITH HELM"
echo "#"
echo "#######################################################################################################"
echo

kubectl label node rhel1 "topology.kubernetes.io/region=west"
kubectl label node rhel2 "topology.kubernetes.io/region=west"
kubectl label node rhel3 "topology.kubernetes.io/region=east"
kubectl label node rhel1 "topology.kubernetes.io/zone=west1"
kubectl label node rhel2 "topology.kubernetes.io/zone=west1"
kubectl label node rhel3 "topology.kubernetes.io/zone=east1"
sleep 2s

cd
mkdir 21.07.2
cd 21.07.2
wget https://github.com/NetApp/trident/releases/download/v21.07.2/trident-installer-21.07.2.tar.gz
tar -xf trident-installer-21.07.2.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

#kubectl create namespace trident
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
#helm install trident netapp-trident/trident-operator --version 21.7.2 -n trident
helm install trident netapp-trident/trident-operator --version 21.7.2 -n trident --create-namespace --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:21.01,operatorImage=registry.demo.netapp.com/trident-operator:21.07.2,tridentImage=registry.demo.netapp.com/trident:21.07.2

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "#"
echo "# 4. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

cd ~/LabNetApp/Kubernetes_v4
sh Scenarios/Scenario02/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 5. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh Scenarios/Scenario05/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 6. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 7. INSTALL & CONFIGURE HARVEST"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh Scenarios/Scenario03/4_Harvest/scenario03_harvest_install.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 8. ENABLE POD SCHEDULING ON THE MASTER NODE"
echo "#"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/master-

echo
echo "#######################################################################################################"
echo "#"
echo "# 9. UPDATE BASHRC"
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
bash