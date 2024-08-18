#!/bin/bash

# PARAMETER 1: Hostname or IP
# PARAMETER 2: Docker Hub Login
# PARAMETER 3: Docker Hub Password

echo "#############################"
echo "# DOCKER LOGIN ON HOST $1"
echo "#############################"
ssh -o "StrictHostKeyChecking no" root@$1 podman login -u $2 -p $3

echo "################################"
echo "# PULLING IMAGES FROM DOCKER HUB"
echo "################################"

echo "####################################"
echo "# netapp/trident:24.06.1"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/netapp/trident:24.06.1

echo "####################################"
echo "# netapp/trident-operator:24.06.1"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/netapp/trident-operator:24.06.1

echo "####################################"
echo "# netapp/trident-autosupport:24.06.0"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/netapp/trident-autosupport:24.06.0