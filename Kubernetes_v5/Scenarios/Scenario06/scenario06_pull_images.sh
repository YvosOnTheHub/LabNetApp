#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep ghost | grep 2.6-alpine | wc -l) -ne 0 ]]
  then
    echo "GHOST 2.6 image already present. Nothing to do"
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

echo "##############################################"
echo "# DOCKER LOGIN & PULL/PUSH GHOST IMAGE"
echo "##############################################"

docker login -u $1 -p $2
docker pull ghost:2.6-alpine
docker tag ghost:2.6-alpine registry.demo.netapp.com/ghost:2.6-alpine
docker push registry.demo.netapp.com/ghost:2.6-alpine
