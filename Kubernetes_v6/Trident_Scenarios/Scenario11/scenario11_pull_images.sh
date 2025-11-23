#!/bin/bash

TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
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

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/mysql/tags/list' | jq -r '.tags[]? | select(.=="5.7.30")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy MYSQL 5.7.30 Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
    docker://quay.io/yvosonthehub/mysql:5.7.30 docker://registry.demo.netapp.com/mysql:5.7.30 \
    --src-tls-verify=false --dest-tls-verify=false 
else
  echo
  echo "##############################################################"
  echo "# MYSQL 5.7.30 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

: <<'ARCHIVE_COMMENT'
if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/mysql 2> /dev/null | grep 5.7.30 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy MYSQL 5.7.30 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/mysql:5.7.30 docker://registry.demo.netapp.com/mysql:5.7.30
else
  echo
  echo "##############################################################"
  echo "# MYSQL 5.7.30 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi
ARCHIVE_COMMENT
