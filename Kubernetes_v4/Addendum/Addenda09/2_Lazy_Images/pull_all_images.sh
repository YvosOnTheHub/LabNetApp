#!/bin/bash

# PARAMETER 1: Hostname or IP
# PARAMETER 2: Docker Hub Login
# PARAMETER 3: Docker Hub Password

echo "#############################"
echo "# DOCKER LOGIN ON HOST $1"
echo "#############################"
ssh -o "StrictHostKeyChecking no" root@$1 docker login -u $2 -p $3

echo "################################"
echo "# PULLING IMAGES FROM DOCKER HUB"
echo "################################"

echo "####################################"
echo "# netapp/trident:21.01.0"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident:21.01.0

echo "####################################"
echo "# netapp/trident-operator:21.01.0"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-operator:21.01.0

echo "####################################"
echo "# netapp/trident-autosupport:21.01"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-autosupport:21.01

echo "####################################"
echo "# ghost:2.6-alpine"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull ghost:2.6-alpine

echo "####################################"
echo "# ghost:3.13-alpine"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull ghost:3.13-alpine

echo "####################################"
echo "# centos:centos7"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull centos:centos7

echo "####################################"
echo "# mysql:5.7"
echo "####################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull mysql:5.7

if [[ ! "$1" =~ ^(rhel1|rhel2|rhel3)$ ]]
  then
    echo "####################################"
    echo "# netapp/trident:21.01.0"
    echo "####################################"
    ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident:21.01.0

    echo "####################################"
    echo "# netapp/trident-operator:21.01.0"
    echo "####################################"
    ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-operator:21.01.0

    echo "####################################"
    echo "# netapp/trident-autosupport:21.01"
    echo "####################################"
    ssh -o "StrictHostKeyChecking no" root@$1 docker pull netapp/trident-autosupport:21.01
fi