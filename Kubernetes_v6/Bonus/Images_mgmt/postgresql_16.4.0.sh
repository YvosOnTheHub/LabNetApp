#!/bin/bash

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/bitnami/postgresql/tags/list' | jq -r '.tags[]? | select(.=="16.4.0-debian-12-r9")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy PostgreSQL 16.4.0 Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
    docker://quay.io/yvosonthehub/bitnami/postgresql:16.4.0-debian-12-r9 docker://registry.demo.netapp.com/bitnami/postgresql:16.4.0-debian-12-r9 \
    --src-tls-verify=false --dest-tls-verify=false 
else
  echo
  echo "##############################################################"
  echo "# PostgreSQL 16.4.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi