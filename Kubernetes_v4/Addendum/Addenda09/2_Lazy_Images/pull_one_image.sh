#!/bin/bash

# PARAMETER 1: Hostname or IP
# PARAMETER 2: Docker Hub Login
# PARAMETER 3: Docker Hub Password
# PARAMETER 4: Image to pull

echo "##############################################"
echo "# DOCKER LOGIN ON HOST $1"
echo "##############################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker login -u $2 -p $3

echo "##############################################"
echo "# PULLING IMAGE $4 FROM DOCKER HUB"
echo "##############################################"
ssh -o "StrictHostKeyChecking no" root@$1 docker pull $4

