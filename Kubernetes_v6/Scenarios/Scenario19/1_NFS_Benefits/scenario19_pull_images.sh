#!/bin/bash

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

if [[ $RATEREMAINING -lt 20 ]];then
  if ! grep -q "dockreg" /etc/containers/registries.conf; then
    echo
    echo "##############################################################"
    echo "# CONFIGURE MIRROR PASS THROUGH FOR IMAGES PULL"
    echo "##############################################################"
  cat <<EOT >> /etc/containers/registries.conf
[[registry]]
prefix = "docker.io"
location = "docker.io"
[[registry.mirror]]
prefix = "docker.io"
location = "dockreg.labs.lod.netapp.com"
EOT
  fi
fi

skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/bitnami/mariadb 2> /dev/null | grep 11.4.2-debian-12-r2 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy MariaDB 11.4 Into Private Repo"
  echo "##############################################################"
  
  skopeo copy docker://docker.io/bitnami/mariadb:11.4.2-debian-12-r2 docker://registry.demo.netapp.com/bitnami/mariadb:11.4.2-debian-12-r2
else
  echo
  echo "##############################################################"
  echo "# MariaDB 11.4 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/bitnami/wordpress 2> /dev/null | grep 6.6.1-debian-12-r1 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy WORDPRESS 6.6.1 (Debian 12-r1) Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/bitnami/wordpress:6.6.1-debian-12-r1 docker://registry.demo.netapp.com/bitnami/wordpress:6.6.1-debian-12-r1
else
  echo
  echo "################################################################################"
  echo "# WORDPRESS 6.6.1 (Debian 12-r1) already in the Private Repo - nothing to do"
  echo "################################################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/bitnami/wordpress 2> /dev/null | grep 6.6.1-debian-12-r3 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy WORDPRESS 6.6.1 (Debian 12-r3) Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/bitnami/wordpress:6.6.1-debian-12-r3 docker://registry.demo.netapp.com/bitnami/wordpress:6.6.1-debian-12-r3
else
  echo
  echo "################################################################################"
  echo "# WORDPRESS 6.6.1 (Debian 12-r3) already in the Private Repo - nothing to do"
  echo "################################################################################"
fi