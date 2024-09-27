#!/bin/bash

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

if [[ $RATEREMAINING -lt 20 ]];then
  if ! grep -q "dockreg" /etc/containers/registries.conf; then
    echo
    echo "##############################################################"
    echo "# CONFIGURE MIRROR PASS THROUGH FOR IMAGES PULL"
    echo "##############################################################"
  cat <<EOT >> /etc/containers/registries.conf
[[registry]]
prefix = "docker.io"
location = "docker.io"
[[registry.mirror]]
prefix = "docker.io"
location = "dockreg.labs.lod.netapp.com"
EOT
  fi
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/ghost 2> /dev/null | grep 2.6-alpine | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy GHOST 2.6 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/ghost:2.6-alpine docker://registry.demo.netapp.com/ghost:2.6-alpine
else
  echo
  echo "##############################################################"
  echo "# GHOST 2.6 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/ghost 2> /dev/null | grep 3.13-alpine | wc -l) -ne 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy GHOST 3.13 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/ghost:3.13-alpine docker://registry.demo.netapp.com/ghost:3.13-alpine
else
  echo
  echo "##############################################################"
  echo "# GHOST 3.13 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi