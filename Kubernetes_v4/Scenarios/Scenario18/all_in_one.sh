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
echo "#######################################################################################################"

sh ../../Addendum/Addenda05/all_in_one.sh
sh ../../Addendum/Addenda13/all_in_one.sh $1 $2
sh ../../Addendum/Addenda14/all_in_one.sh

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18
sh push_scenario_images_to_private_repo.sh $1 $2
sh trident_uninstall.sh


echo "###### Configure local Git variables"
git config --global user.email lod.demo.netapp.com
git config --global user.name "lod"
git config --global credential.helper store
git config --global alias.adcom '!git add -A && git commit -m'
git config --global push.default simple
echo

echo "#######################################################################################################"
echo " Connect to Gitea: http://192.168.0.64:3000/"
echo " Create the administrator account: demo/netapp123/demo@demo.netapp.com"
echo
echo " Run all_in_one_post_process.sh to finish the setup"
echo "#######################################################################################################"