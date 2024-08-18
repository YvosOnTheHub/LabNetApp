#!/bin/bash

# PARAMETER 1: Docker Hub Login
# PARAMETER 2: Docker Hub Password

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

echo "##############################################################"
echo "# SKOPEO LOG INTO REGISTRIES"
echo "##############################################################"

if [ $# -eq 2 ]; then
   skopeo login docker.io -u $1 -p $2
fi

skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

echo "##############################################################"
echo "# SKOPEO COPY INTO PRIVATE REPO"
echo "##############################################################"

skopeo copy docker://docker.io/bitnami/mariadb:11.4.2-debian-12-r2 docker://registry.demo.netapp.com/bitnami/mariadb:11.4.2-debian-12-r2
skopeo copy docker://docker.io/bitnami/wordpress:6.6.1-debian-12-r1 docker://registry.demo.netapp.com/bitnami/wordpress:6.6.1-debian-12-r1
skopeo copy docker://docker.io/bitnami/wordpress:6.6.1-debian-12-r3 docker://registry.demo.netapp.com/bitnami/wordpress:6.6.1-debian-12-r3