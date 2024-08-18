#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# CHECKING HOW MANY IMAGES YOU CAN PULL FROM THE DOCKER HUB"
echo "#"
echo "#######################################################################################################"
echo

TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

if [[ $RATEREMAINING -eq 0 ]];then
    echo "#######################################################################################################"
    echo "# Your anonymous login to the Docker Hub does not have any pull left."
    echo "# Consider using your own credentials"
    echo "#######################################################################################################"
elif [[ $RATEREMAINING -lt 20 ]];then
    echo "#######################################################################################################"
    echo "# Your anonymous login to the Docker Hub does not have many pulls left ($RATEREMAINING)."
    echo "# Consider using your own credentials"
    echo "#######################################################################################################"
else
    echo "#######################################################################################################"
    echo "# Your anonymous login to the Docker Hub seems to have plenty of pulls left ($RATEREMAINING)."
    echo "#######################################################################################################"
fi