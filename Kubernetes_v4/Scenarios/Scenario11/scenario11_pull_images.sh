#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep mysql | grep 5.7.30 | wc -l) -ne 0 ]]
  then
    echo "MYSQL image already present. Nothing to do"
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

if [ $(kubectl get nodes | wc -l) = 4 ];then
  hosts=( "rhel1" "rhel2" "rhel3")
else
  hosts=( "rhel1" "rhel2" "rhel3" "rhel4")
fi

for host in "${hosts[@]}"
do
  echo "##############################################"
  echo "# DOCKER LOGIN ON $host & PULLING MYSQL IMAGE"
  echo "##############################################"
  ssh -o "StrictHostKeyChecking no" root@$host docker login -u $1 -p $2
  ssh -o "StrictHostKeyChecking no" root@$host docker pull mysql:5.7.30
done
