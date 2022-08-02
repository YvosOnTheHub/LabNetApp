#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep argocd | wc -l) -eq 0 ]]; then
  if [ $# -eq 0 ]; then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
  fi

  echo "##############################################"
  echo "# DOCKER LOGIN & PULL/PUSH ARGOCD IMAGES"
  echo "##############################################"
  docker login -u $1 -p $2
  
  docker pull redis:7.0.0-alpine
  docker tag redis:7.0.0-alpine registry.demo.netapp.com/redis:7.0.0-alpine
  docker push registry.demo.netapp.com/redis:7.0.0-alpine
  
  docker pull quay.io/argoproj/argocd:v2.4.3
  docker tag quay.io/argoproj/argocd:v2.4.3 registry.demo.netapp.com/argoproj/argocd:v2.4.3
  docker push registry.demo.netapp.com/argoproj/argocd:v2.4.3

  docker pull ghcr.io/dexidp/dex:v2.30.2
  docker tag ghcr.io/dexidp/dex:v2.30.2 registry.demo.netapp.com/dexidp/dex:v2.30.2
  docker push registry.demo.netapp.com/dexidp/dex:v2.30.2 
fi