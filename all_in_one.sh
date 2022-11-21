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
echo "# 1. INSTALL TRIDENT OPERATOR 22.10.0 WITH HELM"
echo "# 2. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "# 3. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "# 4. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "# 5. INSTALL & CONFIGURE HARVEST"
echo "# 6. ENABLE POD SCHEDULING ON THE MASTER NODE" 
echo "# 7. REMOVE OLD CONTAINER IMAGES" 
echo "# 8. UPDATE BASHRC"
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
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# 1. INSTALL TRIDENT OPERATOR 22.10.0 WITH HELM"
echo "#"
echo "#######################################################################################################"
echo

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario01/2_Helm
if [[ $# -eq 2 ]];then
  sh all_in_one.sh $1 $2
else
  sh all_in_one.sh
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# 2. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario02/all_in_one.sh 

echo
echo "#######################################################################################################"
echo "#"
echo "# 3. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario05/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 4. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
if [[ $# -eq 2 ]];then
  sh ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario03/all_in_one.sh $1 $2
else
  sh ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario03/all_in_one.sh
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# 5. INSTALL & CONFIGURE HARVEST"
echo "#"
echo "#######################################################################################################"
echo

sleep 2s
sh ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario03/4_Harvest/scenario03_harvest_install.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 6. ENABLE POD SCHEDULING ON THE MASTER NODE"
echo "#"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/master-

echo
echo "#######################################################################################################"
echo "#"
echo "# 7. REMOVE OLD CONTAINER IMAGES" 
echo "#"
echo "#######################################################################################################"
echo

docker images | grep trident | grep -v -F 22. | awk '{print $3}' | xargs docker rmi
ssh -o "StrictHostKeyChecking no" root@rhel1 "docker images | grep trident | grep -v -F 22. | awk '{print \$3}' | xargs docker rmi"
ssh -o "StrictHostKeyChecking no" root@rhel2 "docker images | grep trident | grep -v -F 22. | awk '{print \$3}' | xargs docker rmi"

cd ../..
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
bash