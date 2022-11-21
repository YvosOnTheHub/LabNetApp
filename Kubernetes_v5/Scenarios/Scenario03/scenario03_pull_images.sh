#!/bin/bash

# optional parameters
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

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

docker pull grafana/grafana:9.1.4
docker tag grafana/grafana:9.1.4 registry.demo.netapp.com/grafana/grafana:9.1.4
docker push registry.demo.netapp.com/grafana/grafana:9.1.4
