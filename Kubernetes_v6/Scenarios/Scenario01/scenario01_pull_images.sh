#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: docker hub login
# PARAMETER2: docker hub password

if [[ $(podman images | grep registry | grep trident | grep 24.06.1 | wc -l) -ne 0 ]]; then
    echo "TRIDENT 24.06.1 images already present. Nothing to do"
    exit 0
fi

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

echo "##############################################################"
echo "# SKOPEO LOG INTO REGISTRIES"
echo "##############################################################"

if [ $# -eq 2 ]; then
   skopeo login docker.io -u $1 -p $2
fi

skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

echo "##############################################################"
echo "# SKOPEO COPY INTO PRIVATE REPO"
echo "# Multi-arch required for Trident image"
echo "##############################################################"

skopeo copy --multi-arch all docker://docker.io/netapp/trident:24.06.1 docker://registry.demo.netapp.com/trident:24.06.1
skopeo copy docker://docker.io/netapp/trident-operator:24.06.1 docker://registry.demo.netapp.com/trident-operator:24.06.1
skopeo copy docker://docker.io/netapp/trident-autosupport:24.06.0 docker://registry.demo.netapp.com/trident-autosupport:24.06.0
