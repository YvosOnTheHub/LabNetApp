#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep trident | grep 23.07.1 | wc -l) -ne 0 ]]
  then
    echo "TRIDENT 23.07.0 images already present. Nothing to do"
    exit 0
fi

if [ $# -eq 2 ]; then
   docker login -u $1 -p $2
fi

echo "##############################################################"
echo "# PULL TRIDENT IMAGES FROM DOCKER HUB & PUSH TO LOCAL REPO"
echo "##############################################################"
docker pull netapp/trident:23.07.1
docker pull netapp/trident-operator:23.07.1
docker pull netapp/trident-autosupport:23.07.0

docker tag netapp/trident:23.07.1 registry.demo.netapp.com/trident:23.07.1
docker tag netapp/trident-operator:23.07.1 registry.demo.netapp.com/trident-operator:23.07.1
docker tag netapp/trident-autosupport:23.07.0 registry.demo.netapp.com/trident-autosupport:23.07.0

docker push registry.demo.netapp.com/trident:23.07.1
docker push registry.demo.netapp.com/trident-operator:23.07.1
docker push registry.demo.netapp.com/trident-autosupport:23.07.0
