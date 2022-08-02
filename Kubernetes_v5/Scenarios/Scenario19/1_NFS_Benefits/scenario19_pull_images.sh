#!/bin/bash

# PARAMETER 1: Docker Hub Login
# PARAMETER 2: Docker Hub Password

echo "########################################"
echo "# PULLING TRIDENT IMAGES FROM DOCKER HUB"
echo "########################################"

if [[ $# -eq 2 ]];then
    docker login -u $1 -p $2
fi
docker pull bitnami/wordpress:5.8.1-debian-10-r59
docker pull bitnami/wordpress:5.8.2-debian-10-r12
docker pull bitnami/mariadb:10.5.13-debian-10-r0


echo "####################################"
echo "# TAGGING TRIDENT IMAGES"
echo "####################################"

docker tag bitnami/wordpress:5.8.1-debian-10-r59 registry.demo.netapp.com/bitnami/wordpress:5.8.1-debian-10-r59
docker tag bitnami/wordpress:5.8.2-debian-10-r12 registry.demo.netapp.com/bitnami/wordpress:5.8.2-debian-10-r12
docker tag bitnami/mariadb:10.5.13-debian-10-r0 registry.demo.netapp.com/bitnami/mariadb:10.5.13-debian-10-r0


echo "##########################################"
echo "# PUSHING TRIDENT IMAGES TO THE LOCAL REPO"
echo "###########################################"

docker push registry.demo.netapp.com/bitnami/wordpress:5.8.1-debian-10-r59
docker push registry.demo.netapp.com/bitnami/wordpress:5.8.2-debian-10-r12
docker push registry.demo.netapp.com/bitnami/mariadb:10.5.13-debian-10-r0