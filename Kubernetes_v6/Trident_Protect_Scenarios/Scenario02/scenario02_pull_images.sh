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

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi
skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/controller 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Controller Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/controller:25.02.0 docker://registry.demo.netapp.com/controller:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/exechook 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect Exechook Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/exechook:25.02.0 docker://registry.demo.netapp.com/exechook:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/resourcebackup 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceBackup Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/resourcebackup:25.02.0 docker://registry.demo.netapp.com/resourcebackup:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/resourcerestore 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceRestore Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/resourcerestore:25.02.0 docker://registry.demo.netapp.com/resourcerestore:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/resourcedelete 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Trident Protect ResourceDelete Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/resourcedelete:25.02.0 docker://registry.demo.netapp.com/resourcedelete:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/restic 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Restic Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/restic:25.02.0 docker://registry.demo.netapp.com/restic:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/kopia 2> /dev/null | grep 25.02.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Kopia Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/kopia:25.02.0 docker://registry.demo.netapp.com/kopia:25.02.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/kubectl 2> /dev/null | grep 1.30.2 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Kubectl Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/bitnami/kubectl:1.30.2 docker://registry.demo.netapp.com/bitnami/kubectl:1.30.2
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/kube-rbac-proxy 2> /dev/null | grep 0.16.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Kube RBAC Proxy Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/kubebuilder/kube-rbac-proxy:v0.16.0 docker://registry.demo.netapp.com/kubebuilder/kube-rbac-proxy:v0.16.0
fi
