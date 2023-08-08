#!/bin/bash

# PARAMETER 1: Hostname or IP
# PARAMETER 2: Docker Hub Login
# PARAMETER 3: Docker Hub Password

if [[  $(docker images | grep 'netapp/trident' | grep 23.07.0 | wc -l) -ne 3 ]]
  then
    echo "########################################"
    echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB"
    echo "########################################"

    if [[ $# -eq 3 ]];then
       ssh -o "StrictHostKeyChecking no" root@$1 docker login -u $2 -p $3
    fi
    ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident:23.07.0
    ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-operator:23.07.0
    ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-autosupport:23.07.0
fi

echo "####################################"
echo "# TAGGING TRIDENT IMAGES"
echo "####################################"

ssh -o "StrictHostKeyChecking no" root@$1 docker tag netapp/trident:23.07.0 registry.demo.netapp.com/trident:23.07.0
ssh -o "StrictHostKeyChecking no" root@$1 docker tag netapp/trident-operator:23.07.0 registry.demo.netapp.com/trident-operator:23.07.0
ssh -o "StrictHostKeyChecking no" root@$1 docker tag netapp/trident-autosupport:23.07.0 registry.demo.netapp.com/trident-autosupport:23.07.0

echo "##########################################"
echo "# PUSHING TRIDENT IMAGES TO THE LOCAL REPO"
echo "###########################################"

ssh -o "StrictHostKeyChecking no" root@$1 docker push registry.demo.netapp.com/trident:23.07.0
ssh -o "StrictHostKeyChecking no" root@$1 docker push registry.demo.netapp.com/trident-operator:23.07.0
ssh -o "StrictHostKeyChecking no" root@$1 docker push registry.demo.netapp.com/trident-autosupport:23.07.0
