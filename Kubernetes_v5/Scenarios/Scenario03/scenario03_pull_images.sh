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

if [ $(kubectl get nodes | wc -l) = 4 ];then
  hosts=( "rhel2" "rhel3")
else
  hosts=( "rhel2" "rhel3" "rhel4")
fi

for host in "${hosts[@]}"
do
  echo "#########################################################"
  echo "# LOGIN on $host & PULLING IMAGES FROM DOCKER HUB"
  echo "#########################################################"
  ssh -o "StrictHostKeyChecking no" root@$host docker login -u $1 -p $2
  ssh -o "StrictHostKeyChecking no" root@$host docker pull grafana/grafana:7.0.3
  ssh -o "StrictHostKeyChecking no" root@$host docker pull kiwigrid/k8s-sidecar:0.1.151
  ssh -o "StrictHostKeyChecking no" root@$host docker pull busybox:1.31.1
  ssh -o "StrictHostKeyChecking no" root@$host docker pull squareup/ghostunnel:v1.5.2
done

# Managing RHEL1 separatly as Prometheus is already installed there from the beginning
echo "#################################################"
echo "# PULLING BUSYBOX FROM DOCKER HUB ON RHEL1"
echo "#################################################"
ssh -o "StrictHostKeyChecking no" root@rhel1 docker login -u $1 -p $2
ssh -o "StrictHostKeyChecking no" root@rhel1 docker pull busybox:1.31.1


docker login -u $1 -p $2
docker pull grafana/grafana:7.0.3
docker pull kiwigrid/k8s-sidecar:0.1.151
docker pull busybox:1.31.1
docker pull squareup/ghostunnel:v1.5.2

docker tag grafana/grafana:7.0.3 registry.demo.netapp.com/grafana/grafana:7.0.3
docker tag kiwigrid/k8s-sidecar:0.1.151 registry.demo.netapp.com/kiwigrid/k8s-sidecar:0.1.151
docker tag busybox:1.31.1 registry.demo.netapp.com/busybox:1.31.1
docker tag squareup/ghostunnel:v1.5.2 registry.demo.netapp.com/squareup/ghostunnel:v1.5.2

docker push registry.demo.netapp.com/grafana/grafana:7.0.3
docker push registry.demo.netapp.com/kiwigrid/k8s-sidecar:0.1.151
docker push registry.demo.netapp.com/busybox:1.31.1
docker push registry.demo.netapp.com/squareup/ghostunnel:v1.5.2


jettech/kube-webhook-certgen:v1.5.0