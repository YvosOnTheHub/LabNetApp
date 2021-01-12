#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
fi

echo "#############################"
echo "# DOCKER LOGIN ON EACH NODE"
echo "#############################"
ssh -o "StrictHostKeyChecking no" root@rhel1 docker login -u $1 -p $2
ssh -o "StrictHostKeyChecking no" root@rhel2 docker login -u $1 -p $2
ssh -o "StrictHostKeyChecking no" root@rhel3 docker login -u $1 -p $2

if [ $(kubectl get nodes | wc -l) = 5 ]
then
  ssh -o "StrictHostKeyChecking no" root@rhel4 docker login -u $1 -p $2
fi  

echo "#################################################"
echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB ON RHEL1"
echo "#################################################"
ssh -o "StrictHostKeyChecking no" root@rhel1 docker pull netapp/trident:20.10.0
ssh -o "StrictHostKeyChecking no" root@rhel1 docker pull netapp/trident-operator:20.10.0
ssh -o "StrictHostKeyChecking no" root@rhel1 docker pull netapp/trident-autosupport:20.10.0

echo "#################################################"
echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB ON RHEL2"
echo "#################################################"
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull netapp/trident:20.10.0
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull netapp/trident-operator:20.10.0
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull netapp/trident-autosupport:20.10.0

echo "#################################################"
echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB ON RHEL3"
echo "#################################################"
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull netapp/trident:20.10.0
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull netapp/trident-operator:20.10.0
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull netapp/trident-autosupport:20.10.0

if [ $(kubectl get nodes | wc -l) = 5 ]
then
    echo "#################################################"
    echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB ON RHEL4"
    echo "#################################################"
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull netapp/trident:20.10.0
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull netapp/trident-operator:20.10.0
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull netapp/trident-autosupport:20.10.0
fi 
