#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep metallb | wc -l) -eq 0 ]]; then
  if [ $# -eq 0 ]; then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
  fi

  echo "##############################################"
  echo "# DOCKER LOGIN & PULL/PUSH METALLB IMAGE"
  echo "##############################################"
  docker login -u $1 -p $2
  
  docker pull metallb/speaker:v0.9.6
  docker tag metallb/speaker:v0.9.6 registry.demo.netapp.com/metallb/speaker:v0.9.6
  docker push registry.demo.netapp.com/metallb/speaker:v0.9.6
  
  docker pull metallb/controller:v0.9.6
  docker tag metallb/controller:v0.9.6 registry.demo.netapp.com/metallb/controller:v0.9.6
  docker push registry.demo.netapp.com/metallb/controller:v0.9.6
fi