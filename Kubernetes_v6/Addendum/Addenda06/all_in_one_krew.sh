#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL KREW"
echo "#"
echo "#######################################################################################################"
echo

(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL SOME PLUGINS"
echo "#"
echo "#######################################################################################################"
echo

kubectl krew install get-all
kubectl krew install view-utilization
kubectl krew install tree
kubectl krew install view-secret
kubectl krew install stern