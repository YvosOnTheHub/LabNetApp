#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep trident | grep 22.01.1 | wc -l) -ne 0 ]]
  then
    echo "TRIDENT 22.01.1 images already present. Nothing to do"
    exit 0
fi

if [ $# -eq 2 ]; then
   docker login -u $1 -p $2
fi

echo "##############################################################"
echo "# PULL TRIDENT IMAGES FROM DOCKER HUB & PUSH TO LOCAL REPO"
echo "##############################################################"
docker pull netapp/trident:22.01.1
docker pull netapp/trident-operator:22.01.1
docker pull netapp/trident-autosupport:22.01

docker tag netapp/trident:22.01.1 registry.demo.netapp.com/trident:22.01.1
docker tag netapp/trident-operator:22.01.1 registry.demo.netapp.com/trident-operator:22.01.1
docker tag netapp/trident-autosupport:22.01 registry.demo.netapp.com/trident-autosupport:22.01

docker push registry.demo.netapp.com/trident:22.01.1
docker push registry.demo.netapp.com/trident-operator:22.01.1
docker push registry.demo.netapp.com/trident-autosupport:22.01
