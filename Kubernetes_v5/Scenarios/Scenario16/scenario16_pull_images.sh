#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep registry | grep dbench | wc -l) -ne 0 ]]
  then
    echo "DBENCH image already present. Nothing to do"
    exit 0
fi

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
fi

echo "##############################################"
echo "# DOCKER LOGIN & PULL/PUSH DBENCH IMAGE"
echo "##############################################"

docker pull ndrpnt/dbench:1.0.0
docker tag ndrpnt/dbench:1.0.0 registry.demo.netapp.com/dbench:1.0.0
docker push registry.demo.netapp.com/dbench:1.0.0