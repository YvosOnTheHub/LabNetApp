#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER 1: Docker Hub Login
# PARAMETER 2: Docker Hub Password

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

if [ $# -eq 2 ]; then
    skopeo login docker.io -u $1 -p $2
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

skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

echo "####################################################"
echo "# PULL/PUSH TRIDENT 24.06.0 IMAGES FROM DOCKER HUB"
echo "####################################################"
skopeo copy --multi-arch all docker://docker.io/netapp/trident:24.06.0 docker://registry.demo.netapp.com/trident:24.06.0
skopeo copy docker://docker.io/netapp/trident-operator:24.06.0 docker://registry.demo.netapp.com/trident-operator:24.06.0
skopeo copy docker://docker.io/netapp/trident-autosupport:24.06.0 docker://registry.demo.netapp.com/trident-autosupport:24.06.0

echo "####################################################"
echo "# PULL/PUSH TRIDENT 24.06.1 IMAGES FROM DOCKER HUB"
echo "####################################################"
skopeo copy --multi-arch all docker://docker.io/netapp/trident:24.06.1 docker://registry.demo.netapp.com/trident:24.06.1
skopeo copy docker://docker.io/netapp/trident-operator:24.06.1 docker://registry.demo.netapp.com/trident-operator:24.06.1

echo "####################################################"
echo "# PULL/PUSH GHOST IMAGES FROM DOCKER HUB"
echo "####################################################"
skopeo copy docker://docker.io/ghost:2.6-alpine docker://registry.demo.netapp.com/ghost:2.6-alpine
skopeo copy docker://docker.io/ghost:3.13-alpine docker://registry.demo.netapp.com/ghost:3.13-alpine