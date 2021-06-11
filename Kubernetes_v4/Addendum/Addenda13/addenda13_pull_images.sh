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

echo "#########################################################"
echo "# PULLING GITEA IMAGES FROM DOCKER HUB"
echo "#########################################################"
ssh -o "StrictHostKeyChecking no" root@rhel4 docker login -u $1 -p $2
ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull gitea/gitea:1.14.2
ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull mysql:8

