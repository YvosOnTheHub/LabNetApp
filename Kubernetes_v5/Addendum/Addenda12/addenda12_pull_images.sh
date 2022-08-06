#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep argocd | wc -l) -eq 0 ]]; then
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
fi

echo "##############################################"
echo "# PULL/PUSH ARGOCD IMAGES"
echo "##############################################"
  
docker pull redis:7.0.0-alpine
docker tag redis:7.0.0-alpine registry.demo.netapp.com/redis:7.0.0-alpine
docker push registry.demo.netapp.com/redis:7.0.0-alpine
  
docker pull quay.io/argoproj/argocd:v2.4.3
docker tag quay.io/argoproj/argocd:v2.4.3 registry.demo.netapp.com/argoproj/argocd:v2.4.3
docker push registry.demo.netapp.com/argoproj/argocd:v2.4.3

docker pull ghcr.io/dexidp/dex:v2.30.2
docker tag ghcr.io/dexidp/dex:v2.30.2 registry.demo.netapp.com/dexidp/dex:v2.30.2
docker push registry.demo.netapp.com/dexidp/dex:v2.30.2 
