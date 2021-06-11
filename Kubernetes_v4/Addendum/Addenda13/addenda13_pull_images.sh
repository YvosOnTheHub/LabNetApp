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
docker login -u $1 -p $2
docker pull gitea/gitea:1.14.2
docker pull mysql:8

