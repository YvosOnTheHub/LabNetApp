#!/bin/bash

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/busybox/tags/list' | jq -r '.tags[]? | select(.=="1.35.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Busybox 1.35.0 Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
    docker://quay.io/yvosonthehub/busybox:1.35.0 docker://registry.demo.netapp.com/busybox:1.35.0 \
    --src-tls-verify=false --dest-tls-verify=false 
else
  echo
  echo "##############################################################"
  echo "# Busybox 1.35.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi