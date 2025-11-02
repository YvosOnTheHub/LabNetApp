#!/bin/bash

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