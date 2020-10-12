#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# Install Trident Operator 20.07.1"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario01/2_Operator/all_in_one.sh

echo "#######################################################################################################"
echo "#"
echo "# Upgrade Kubernetes from 1.15 to 1.16"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda04/upgrade_to_1.16/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# Upgrade Kubernetes from 1.16 to 1.17"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda04/upgrade_to_1.17/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# Install MetalLB"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda07/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# Install NAS Backends for Trident"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario02/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# Install & Configure Prometheus & Grafana"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# Update Bash"
echo "#"
echo "#######################################################################################################"
echo

cat <<EOT >> ~/.bashrc
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k

alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
bash