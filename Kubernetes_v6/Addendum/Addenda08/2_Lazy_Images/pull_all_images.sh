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
echo "# netapp/trident:25.02.0"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/netapp/trident:25.02.0

echo "####################################"
echo "# netapp/trident-operator:25.02.0"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/netapp/trident-operator:25.02.0

echo "####################################"
echo "# netapp/trident-autosupport:25.02.0"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/netapp/trident-autosupport:25.02.0

echo "####################################"
echo "# ghost:2.6-alpine"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/ghost:2.6-alpine

echo "####################################"
echo "# ghost:3.13-alpine"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/ghost:3.13-alpine

echo "####################################"
echo "# centos:centos7"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/busybox:1.35.0

echo "####################################"
echo "# mysql:5.7"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 podman pull docker.io/mysql:5.7
