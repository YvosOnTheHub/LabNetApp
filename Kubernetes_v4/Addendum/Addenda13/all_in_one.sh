#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL GITEA on RHEL4"
echo "#"
echo "#######################################################################################################"
echo

ssh -o "StrictHostKeyChecking no" root@rhel4 "svn export https://github.com/YvosOnTheHub/LabNetApp.git/trunk/Kubernetes_v4/Addendum/Addenda13"
ssh -o "StrictHostKeyChecking no" root@rhel4 "cd Addenda13"
ssh -o "StrictHostKeyChecking no" root@rhel4 "docker-compose up -d"