#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(podman images | grep registry | grep dbench | wc -l) -ne 0 ]]; then
    echo "DBENCH image already present. Nothing to do"
    exit 0
fi

if [ $# -eq 2 ]; then
  podman login -u $1 -p $2
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

podman login -u registryuser -p Netapp1! registry.demo.netapp.com

echo "##############################################"
echo "# PULL/PUSH DBENCH IMAGE"
echo "##############################################"

podman pull docker.io/ndrpnt/dbench:1.0.0
podman tag docker.io/ndrpnt/dbench:1.0.0 registry.demo.netapp.com/dbench:1.0.0
podman push registry.demo.netapp.com/dbench:1.0.0