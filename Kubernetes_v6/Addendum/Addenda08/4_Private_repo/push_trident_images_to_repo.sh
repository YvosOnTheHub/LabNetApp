#!/bin/bash

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Multi-Arch TRIDENT Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --multi-arch all --dest-creds 'registryuser:Netapp1!' \
  docker://quay.io/netapp/trident:25.10.0 docker://registry.demo.netapp.com/trident:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident-operator/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT OPERATOR Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://quay.io/netapp/trident-operator:25.10.0 docker://registry.demo.netapp.com/trident-operator:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident-autosupport/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT AUTOSUPPORT Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://quay.io/netapp/trident-autosupport:25.10.0 docker://registry.demo.netapp.com/trident-autosupport:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi