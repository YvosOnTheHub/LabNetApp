#!/bin/bash

if ! grep -q "dockreg" /etc/containers/registries.conf; then
  echo
  echo "##############################################################"
  echo "# CONFIGURE MIRROR PASS THROUGH FOR "
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




: <<'ARCHIVE_COMMENT'
if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi

skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Multi-Arch TRIDENT Into Private Repo"
  echo "##############################################################"
  skopeo copy --multi-arch all docker://docker.io/netapp/trident:25.10.0 docker://registry.demo.netapp.com/trident:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident-operator 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT OPERATOR Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/trident-operator:25.10.0 docker://registry.demo.netapp.com/trident-operator:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident-autosupport 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT AUTOSUPPORT Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/trident-autosupport:25.10.0 docker://registry.demo.netapp.com/trident-autosupport:25.10.0
fi
ARCHIVE_COMMENT