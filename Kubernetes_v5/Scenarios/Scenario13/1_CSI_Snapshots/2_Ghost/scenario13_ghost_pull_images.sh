#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep ghost | grep 3.13-alpine | wc -l) -ne 0 ]]; then
    echo "GHOST 3.13 image already present. Nothing to do"
    exit 0
fi

if [[ $(yum info jq -y 2> /dev/null | grep Repo | awk '{ print $3 }') != "installed" ]]; then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi

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

echo "##############################################"
echo "# PULL/PUSH GHOST IMAGES"
echo "##############################################"

docker pull ghost:2.6-alpine
docker tag ghost:2.6-alpine registry.demo.netapp.com/ghost:2.6-alpine
docker push registry.demo.netapp.com/ghost:2.6-alpine

docker pull ghost:3.13-alpine
docker tag ghost:3.13-alpine registry.demo.netapp.com/ghost:3.13-alpine
docker push registry.demo.netapp.com/ghost:3.13-alpine
