#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep busybox | grep 35 | wc -l) -ne 0 ]]
  then
    echo "BUSYBOX image already present. Nothing to do"
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
echo "# DOCKER LOGIN & PULL/PUSH BUSYBOX IMAGE"
echo "##############################################"
docker login -u $1 -p $2
docker pull busybox:1.35.0
docker tag busybox:1.35.0 registry.demo.netapp.com/busybox:1.35.0
docker push registry.demo.netapp.com/busybox:1.35.0
