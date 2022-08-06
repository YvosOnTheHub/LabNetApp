#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep metallb | wc -l) -eq 0 ]]; then
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
  
docker pull metallb/speaker:v0.9.6
docker tag metallb/speaker:v0.9.6 registry.demo.netapp.com/metallb/speaker:v0.9.6
docker push registry.demo.netapp.com/metallb/speaker:v0.9.6
  
docker pull metallb/controller:v0.9.6
docker tag metallb/controller:v0.9.6 registry.demo.netapp.com/metallb/controller:v0.9.6
docker push registry.demo.netapp.com/metallb/controller:v0.9.6
