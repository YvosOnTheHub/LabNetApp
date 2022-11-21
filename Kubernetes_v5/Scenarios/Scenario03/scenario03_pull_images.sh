#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password


if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
fi

docker login -u $1 -p $2
docker pull grafana/grafana:9.1.4
docker tag grafana/grafana:9.1.4 registry.demo.netapp.com/grafana/grafana:9.1.4
docker push registry.demo.netapp.com/grafana/grafana:9.1.4
