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
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"${OS}_${ARCH}" &&
  "$KREW" install krew
)

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

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

bash