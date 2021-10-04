#!/bin/bash

# PARAMETER 1: Docker Hub Login
# PARAMETER 2: Docker Hub Password

if [[ $(yum info jq -y | grep Repo | awk '{ print $3 }') != "installed" ]]
  then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi




if [[  $(docker images | grep 'netapp/trident' | grep 21.07.1 | wc -l) -ne 2 ]];then
  if [[ $# -ne 2 ]];then
    TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
    RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

    if [[ $RATEREMAINING -eq 0 ]];then
      echo "----------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have any pull request left. Consider using your own credentials."
      echo "----------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0

    elif [[ $RATEREMAINING -lt 20 ]];then
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have many pull requests left ($RATEREMAINING). Consider using your own credentials"
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
    else
      echo "--------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub seems to have plenty of pull requests left ($RATEREMAINING)."
      echo "--------------------------------------------------------------------------------------------"
    fi
  fi

  echo "########################################"
  echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB"
  echo "########################################"

  docker login -u $1 -p $2
  docker pull netapp/trident:21.07.1
  docker pull netapp/trident:21.07.2
  docker pull netapp/trident-operator:21.07.1
  docker pull netapp/trident-operator:21.07.2
  docker pull netapp/trident-autosupport:21.01
fi

echo "####################################"
echo "# TAGGING TRIDENT IMAGES"
echo "####################################"

docker tag netapp/trident:21.07.1 registry.demo.netapp.com/trident:21.07.1
docker tag netapp/trident:21.07.2 registry.demo.netapp.com/trident:21.07.2
docker tag netapp/trident-operator:21.07.1 registry.demo.netapp.com/trident-operator:21.07.1
docker tag netapp/trident-operator:21.07.2 registry.demo.netapp.com/trident-operator:21.07.2
docker tag netapp/trident-autosupport:21.01 registry.demo.netapp.com/trident-autosupport:21.01

echo "##########################################"
echo "# PUSHING TRIDENT IMAGES TO THE LOCAL REPO"
echo "###########################################"

docker push registry.demo.netapp.com/trident:21.07.1
docker push registry.demo.netapp.com/trident:21.07.2
docker push registry.demo.netapp.com/trident-operator:21.07.1
docker push registry.demo.netapp.com/trident-operator:21.07.2
docker push registry.demo.netapp.com/trident-autosupport:21.01

if [[  $(docker images | grep 'ghost' | grep 2.6 | wc -l) -ne 1 ]]
  then
    echo "########################################"
    echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB"
    echo "########################################"

    docker login -u $1 -p $2
    docker pull ghost:2.6-alpine
    docker pull ghost:3.13-alpine
fi

echo "####################################"
echo "# TAG & PUSH OTHER IMAGES"
echo "####################################"

docker tag ghost:2.6-alpine registry.demo.netapp.com/ghost:2.6-alpine
docker tag ghost:3.13-alpine registry.demo.netapp.com/ghost:3.13-alpine
docker push registry.demo.netapp.com/ghost:2.6-alpine
docker push registry.demo.netapp.com/ghost:3.13-alpine
