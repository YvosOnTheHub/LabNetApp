#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

echo "#######################################################################################################"
echo " 1. Install MetalLB on Kubernetes"
echo " 2. Install Gitea on RHEL4"
echo " 3. Install ArgoCD on Kubernetes"
echo " 4. Push Scenario Docker Images to private repo"
echo " 5. Uninstall Trident"
echo " 6. Configuration local Git variables"
echo " 7. Create a Git repository"
echo " 8. Push data to the repository"
echo " 9. Update .bashrc (if not already done)"
echo "#######################################################################################################"

sh ../../Addendum/Addenda05/all_in_one.sh
sh ../../Addendum/Addenda13/all_in_one.sh $1 $2
sh ../../Addendum/Addenda14/all_in_one.sh

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18
sh push_scenario_images_to_private_repo.sh $1 $2
sh trident_uninstall.sh

git config --global user.email lod.demo.netapp.com
git config --global user.name "lod"
git config --global credential.helper store
git config --global alias.adcom '!git add -A && git commit -m'
git config --global push.default simple

echo
echo "#######################################################################################################"
echo " Connect to Gitea: http://192.168.0.64:3000/"
echo " Create the administrator account: demo/netapp123/demo@demo.netapp.com"
echo "#######################################################################################################"
echo

read -rsp $'Press any key to continue once Gitea configuration is done...\n' -n1 key

curl -X POST "http://192.168.0.64:3000/api/v1/user/repos" -u demo:netapp123 -H "accept: application/json" -H "content-type: application/json" -d '{
  "name":"scenario18",
  "description": "argocd repo"
}'

echo
echo "###### Push Data to the Repository"
echo "# You are going to be asked to enter the Gitea login & pwd: demo/netapp123"
echo "######"
echo
cp -R ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18/Repository ~/
cd ~/Repository
git init
git add .
git commit -m "initial commit"
git remote add origin http://192.168.0.64:3000/demo/scenario18.git
git push -u origin master


if [[  $(more .bashrc | grep kedit | wc -l) -ne 0 ]];then
  echo
  echo "#######################################################################################################"
  echo "#"
  echo "# UPDATE BASHRC"
  echo "#"
  echo "#######################################################################################################"
  echo

  cp ~/.bashrc ~/.bashrc.bak
  cat <<EOT >> ~/.bashrc
  source <(kubectl completion bash)
  complete -F __start_kubectl k

  alias kc='kubectl create'
  alias kg='kubectl get'
  alias kdel='kubectl delete'
  alias kdesc='kubectl describe'
  alias kedit='kubectl edit'
  alias trident='tridentctl -n trident'
  EOT
  bash
fi