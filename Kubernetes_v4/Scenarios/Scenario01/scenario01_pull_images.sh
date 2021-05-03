#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

# When starting the Lab, the 3 main Prometheus/Grafana images coming from DockerHub are already present on RHEL1.
# We will download them on the other hosts.

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
fi

echo "#############################"
echo "# DOCKER LOGIN ON EACH NODE"
echo "#############################"
ssh -o "StrictHostKeyChecking no" root@rhel2 docker login -u $1 -p $2
ssh -o "StrictHostKeyChecking no" root@rhel3 docker login -u $1 -p $2

if [ $(kubectl get nodes | wc -l) = 5 ]
then
  ssh -o "StrictHostKeyChecking no" root@rhel4 docker login -u $1 -p $2
fi  

echo "#################################################"
echo "# PULLING IMAGES FROM DOCKER HUB ON RHEL2"
echo "#################################################"
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull grafana/grafana:7.0.3
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull kiwigrid/k8s-sidecar:0.1.151
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull busybox:1.31.1
ssh -o "StrictHostKeyChecking no" root@rhel2 docker pull squareup/ghostunnel:v1.5.2

echo "#################################################"
echo "# PULLING IMAGES FROM DOCKER HUB ON RHEL3"
echo "#################################################"
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull grafana/grafana:7.0.3
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull kiwigrid/k8s-sidecar:0.1.151
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull busybox:1.31.1
ssh -o "StrictHostKeyChecking no" root@rhel3 docker pull squareup/ghostunnel:v1.5.2

if [ $(kubectl get nodes | wc -l) = 5 ]
then
    echo "#################################################"
    echo "# PULLING IMAGES FROM DOCKER HUB ON RHEL4"
    echo "#################################################"
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull grafana/grafana:7.0.3
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull kiwigrid/k8s-sidecar:0.1.151
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull busybox:1.31.1
    ssh -o "StrictHostKeyChecking no" root@rhel4 docker pull squareup/ghostunnel:v1.5.2
fi 

echo "#################################################"
echo "# PULLING BUSYBOX FROM DOCKER HUB ON RHEL1"
echo "#################################################"

ssh -o "StrictHostKeyChecking no" root@rhel1 docker login -u $1 -p $2
ssh -o "StrictHostKeyChecking no" root@rhel1 docker pull busybox:1.31.1