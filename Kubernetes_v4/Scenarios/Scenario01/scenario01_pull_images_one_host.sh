#!/bin/bash

# PARAMETER1: Host
# PARAMETER2: Docker hub login
# PARAMETER3: Docker hub password

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Host"
    echo " - Parameter2: Docker hub login"
    echo " - Parameter3: Docker hub password"
    exit 0
fi

echo "#########################################################"
echo "# LOGIN on $1 & PULLING TRIDENT IMAGES FROM DOCKER HUB"
echo "#########################################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker login -u $2 -p $3
ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident:21.07.1
ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-operator:21.07.1
ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-autosupport:21.01