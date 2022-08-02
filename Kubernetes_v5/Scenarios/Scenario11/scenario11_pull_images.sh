#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep mysql | grep 5.7.30 | wc -l) -ne 0 ]]
  then
    echo "MYSQL image already present. Nothing to do"
    exit 0
fi

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
fi

echo "###########################################################"
echo "# DOCKER LOGIN & PULL/PUSH MYSQL IMAGE TO PRIVATE REPO"
echo "###########################################################"
docker login -u $1 -p $2
docker pull mysql:5.7.30
docker tag mysql:5.7.30 registry.demo.netapp.com/mysql:5.7.30
docker push registry.demo.netapp.com/mysql:5.7.30