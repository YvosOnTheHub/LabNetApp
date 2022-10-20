#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER 1: Docker Hub Login
# PARAMETER 2: Docker Hub Password

if [[ $(yum info jq -y | grep Repo | awk '{ print $3 }') != "installed" ]]
  then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi


if [[  $(docker images | grep 'netapp/trident' | grep 22.04.0 | wc -l) -ne 3 ]];then
  if [ $# -eq 2 ]; then
    docker login -u $1 -p $2
  else
    TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
    RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

    if [[ $RATEREMAINING -lt 20 ]];then
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have many pull requests left ($RATEREMAINING). Consider using your own credentials"
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
    fi
  fi

  echo "########################################"
  echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB"
  echo "########################################"
 
  if [[  $(docker images | grep registry | grep trident | grep 22.07.0 | wc -l) -eq 0 ]]; then
    docker pull netapp/trident:22.07.0
    docker pull netapp/trident-operator:22.07.0
    docker pull netapp/trident-autosupport:22.07.0
  fi

  docker pull netapp/trident:22.04.0
  docker pull netapp/trident-operator:22.04.0
  docker pull netapp/trident-autosupport:22.04.0
fi

echo "####################################"
echo "# TAGGING/PUSHING TRIDENT IMAGES"
echo "####################################"

if [[  $(docker images | grep registry | grep trident | grep 22.07.0 | wc -l) -eq 0 ]]; then
  docker tag netapp/trident:22.07.0 registry.demo.netapp.com/trident:22.07.0
  docker tag netapp/trident-operator:22.07.0 registry.demo.netapp.com/trident-operator:22.07.0
  docker tag netapp/trident-autosupport:22.07.0 registry.demo.netapp.com/trident-autosupport:22.07.0

  docker push registry.demo.netapp.com/trident:22.07.0
  docker push registry.demo.netapp.com/trident-operator:22.07.0
  docker push registry.demo.netapp.com/trident-autosupport:22.07.0
fi

docker tag netapp/trident:22.04.0 registry.demo.netapp.com/trident:22.04.0
docker tag netapp/trident-operator:22.04.0 registry.demo.netapp.com/trident-operator:22.04.0
docker tag netapp/trident-autosupport:22.04.0 registry.demo.netapp.com/trident-autosupport:22.04.0
docker push registry.demo.netapp.com/trident:22.04.0
docker push registry.demo.netapp.com/trident-operator:22.04.0
docker push registry.demo.netapp.com/trident-autosupport:22.04.0


if [[  $(docker images | grep 'ghost' | grep 2.6 | wc -l) -ne 1 ]]
  then
    echo "########################################"
    echo "# PULLING GHOST IMAGES FROM DOCKER HUB"
    echo "########################################"

    docker pull ghost:2.6-alpine
    docker pull ghost:3.13-alpine
fi

echo "####################################"
echo "# TAG & PUSH GHOST IMAGES"
echo "####################################"

docker tag ghost:2.6-alpine registry.demo.netapp.com/ghost:2.6-alpine
docker tag ghost:3.13-alpine registry.demo.netapp.com/ghost:3.13-alpine
docker push registry.demo.netapp.com/ghost:2.6-alpine
docker push registry.demo.netapp.com/ghost:3.13-alpine
