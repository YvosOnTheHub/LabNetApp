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

: <<'ARCHIVE_COMMENT'
# test if Skopeo is installed
if ! dnf -q list installed skopeo >/dev/null 2>&1; then
  # test repo availability 
  REPO_URL='http://repomirror-rtp.eng.netapp.com/rhel/9server-x86_64//rhel-9-for-x86_64-appstream-rpms/repodata/repomd.xml'

  if curl -sSfI "$REPO_URL" >/dev/null 2>&1; then
    echo "##############################################################"
    echo "# INSTALL SKOPEO"
    echo "##############################################################"
    dnf install -y skopeo
  fi
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/busybox 2> /dev/null | grep 1.35.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Busybox 1.35.0 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/busybox:1.35.0 docker://registry.demo.netapp.com/busybox:1.35.0
else
  echo
  echo "##############################################################"
  echo "# Busybox 1.35.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi
ARCHIVE_COMMENT