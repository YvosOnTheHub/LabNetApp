#!/bin/bash

echo "############################################"
echo "### Trident Protect images mgmt"
echo "############################################"

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

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/controller/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 1. Skopeo Copy Trident Protect Controller Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
    docker://docker.io/netapp/controller:25.10.0 docker://registry.demo.netapp.com/controller:25.10.0 \
    --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/exechook/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 2. Skopeo Copy Trident Protect Exechook Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/exechook:25.10.0 docker://registry.demo.netapp.com/exechook:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/resourcebackup/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 3.Skopeo Copy Trident Protect ResourceBackup Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/resourcebackup:25.10.0 docker://registry.demo.netapp.com/resourcebackup:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/resourcerestore/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 4. Skopeo Copy Trident Protect ResourceRestore Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/resourcerestore:25.10.0 docker://registry.demo.netapp.com/resourcerestore:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/resourcedelete/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 5. Skopeo Copy Trident Protect ResourceDelete Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/resourcedelete:25.10.0 docker://registry.demo.netapp.com/resourcedelete:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/restic/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 6. Skopeo Copy Trident Protect Restic Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/restic:25.10.0 docker://registry.demo.netapp.com/restic:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/kopia/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 7. Skopeo Copy Trident Protect Kopia Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/kopia:25.10.0 docker://registry.demo.netapp.com/kopia:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/kopiablockrestore/tags/list' | jq -r '.tags[]? | select(.=="25.10.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 8. Skopeo Copy Trident Protect Kopia Block Restore Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/kopiablockrestore:25.10.0 docker://registry.demo.netapp.com/kopiablockrestore:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
fi

if [[ -z "$(curl -s -u registryuser:Netapp1! 'https://registry.demo.netapp.com/v2/trident-protect-utils/tags/list' | jq -r '.tags[]? | select(.=="v1.0.0")')" ]]; then
  echo
  echo "##############################################################"
  echo "# 9. Skopeo Copy Trident Protect Trident Protect Utils Into Private Repo"
  echo "##############################################################"
  podman run --rm quay.io/containers/skopeo:latest copy --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/trident-protect-utils:v1.0.0 docker://registry.demo.netapp.com/trident-protect-utils:v1.0.0 \
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

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/controller 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Controller Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/controller:25.10.0 docker://registry.demo.netapp.com/controller:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/exechook 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Exechook Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/exechook:25.10.0 docker://registry.demo.netapp.com/exechook:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/resourcebackup 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceBackup Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/resourcebackup:25.10.0 docker://registry.demo.netapp.com/resourcebackup:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/resourcerestore 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceRestore Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/resourcerestore:25.10.0 docker://registry.demo.netapp.com/resourcerestore:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/resourcedelete 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceDelete Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/resourcedelete:25.10.0 docker://registry.demo.netapp.com/resourcedelete:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/restic 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Restic Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/restic:25.10.0 docker://registry.demo.netapp.com/restic:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/kopia 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Kopia Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/kopia:25.10.0 docker://registry.demo.netapp.com/kopia:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/kopiablockrestore 2> /dev/null | grep 25.10.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Kopia Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/kopiablockrestore:25.10.0 docker://registry.demo.netapp.com/kopiablockrestore:25.10.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident-protect-utils 2> /dev/null | grep 1.0.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect tools Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/trident-protect-utils:v1.0.0 docker://registry.demo.netapp.com/trident-protect-utils:v1.0.0
fi
ARCHIVE_COMMENT