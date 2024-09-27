#!/bin/bash

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

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