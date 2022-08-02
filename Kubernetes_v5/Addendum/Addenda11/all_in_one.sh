#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL GITEA on RHEL4"
echo "#"
echo "#######################################################################################################"
echo

cd ~/LabNetApp/Kubernetes_v5/Addendum/Addenda11
sh addenda11_pull_images.sh $1 $2
ssh -o "StrictHostKeyChecking no" root@rhel4 "svn export https://github.com/YvosOnTheHub/LabNetApp.git/trunk/Kubernetes_v5/Addendum/Addenda11"
ssh -o "StrictHostKeyChecking no" root@rhel4 "cd Addenda11 && docker-compose up -d"
