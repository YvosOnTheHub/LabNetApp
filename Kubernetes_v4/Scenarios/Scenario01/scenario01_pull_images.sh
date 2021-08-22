#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[  $(docker images | grep trident | grep 21.07.1 | wc -l) -ne 0 ]]
  then
    echo "TRIDENT 21.07.1 images already present. Nothing to do"
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
  echo "#########################################################"
  echo "# LOGIN on $host & PULLING TRIDENT IMAGES FROM DOCKER HUB"
  echo "#########################################################"
  ssh -o "StrictHostKeyChecking no" root@$host docker login -u $1 -p $2
  ssh -o "StrictHostKeyChecking no" root@$host docker pull netapp/trident:21.07.1
  ssh -o "StrictHostKeyChecking no" root@$host docker pull netapp/trident-operator:21.07.1
  ssh -o "StrictHostKeyChecking no" root@$host docker pull netapp/trident-autosupport:21.01
done