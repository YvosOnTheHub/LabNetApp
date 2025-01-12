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

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/bitnami/postgresql 2> /dev/null | grep 16.4.0-debian-12-r9 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy PostgreSL 16.4.0 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/bitnami/postgresql:16.4.0-debian-12-r9 docker://registry.demo.netapp.com/bitnami/postgresql:16.4.0-debian-12-r9
else
  echo
  echo "##############################################################"
  echo "# PostgreSL 16.4.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi