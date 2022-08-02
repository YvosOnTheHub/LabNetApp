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
echo "# 1. CLEAN UP THE CURRENT ENVIRONMENT & PUSH TRIDENT IMAGES TO PRIVATE REPO"
echo "# 2. INSTALL TRIDENT OPERATOR 22.01.1 WITH HELM"
echo "# 3. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "# 4. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "# 5. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "# 6. INSTALL & CONFIGURE HARVEST"
echo "# 7. ENABLE POD SCHEDULING ON THE MASTER NODE" 
echo "# 8. REMOVE OLD CONTAINER IMAGES" 
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

  cd ~/LabNetApp/Kubernetes_v5
  sh Addendum/Addenda08/2_Lazy_Images/pull_setup_images.sh rhel1 $1 $2
  sh Addendum/Addenda08/2_Lazy_Images/pull_setup_images.sh rhel2 $1 $2
  sh Addendum/Addenda08/2_Lazy_Images/pull_setup_images.sh rhel3 $1 $2
fi


echo
echo "#######################################################################################################"
echo "#"
echo "# 1. CLEAN UP THE CURRENT ENVIRONMENT & PUSH TRIDENT IMAGES TO PRIVATE REPO"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
cd ~/LabNetApp/Kubernetes_v5
sh Scenarios/Scenario01/2_Helm/trident_uninstall.sh
sh Scenarios/Scenario01/scenario01_pull_images.sh $1 $2

echo
echo "#######################################################################################################"
echo "#"
echo "# 2. INSTALL TRIDENT OPERATOR 22.01.1 WITH HELM"
echo "#"
echo "#######################################################################################################"
echo

kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite
kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite
sleep 2s

cd
mkdir 22.01.1
cd 22.01.1
wget https://github.com/NetApp/trident/releases/download/v22.01.1/trident-installer-22.01.1.tar.gz
tar -xf trident-installer-22.01.1.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 22.1.1 -n trident --create-namespace --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:22.01,operatorImage=registry.demo.netapp.com/trident-operator:22.01.1,tridentImage=registry.demo.netapp.com/trident:22.01.1

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "#"
echo "# 3. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

cd ~/LabNetApp/Kubernetes_v5
sh Scenarios/Scenario02/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 4. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh Scenarios/Scenario05/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 5. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 6. INSTALL & CONFIGURE HARVEST"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh Scenarios/Scenario03/4_Harvest/scenario03_harvest_install.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 7. ENABLE POD SCHEDULING ON THE MASTER NODE"
echo "#"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/master-

echo
echo "#######################################################################################################"
echo "#"
echo "# 8. REMOVE OLD CONTAINER IMAGES" 
echo "#"
echo "#######################################################################################################"
echo

docker images | grep trident | grep -v -F 22. | awk '{print $3}' | xargs docker rmi
ssh -o "StrictHostKeyChecking no" root@rhel1 "docker images | grep trident | grep -v -F 22. | awk '{print $3}' | xargs docker rmi"
ssh -o "StrictHostKeyChecking no" root@rhel2 "docker images | grep trident | grep -v -F 22. | awk '{print $3}' | xargs docker rmi"

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