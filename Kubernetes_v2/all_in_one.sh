#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# ALL IN ONE SCRIPT THAT PERFORMS THE FOLLOWING TASKS:"
echo "#"
echo "# 1. UPGRADE KUBERNETES FROM 1.15 TO 1.16"
echo "# 2. UPGRADE KUBERNETES FROM 1.16 TO 1.17"
echo "# 3. INSTALL METALLB"
echo "# 4. INSTALL TRIDENT OPERATOR 20.10.0"
echo "# 5. INSTALL NAS BACKENDS FOR TRIDENT"
echo "# 6. INSTALL & CONFIGURE PROMETHEUS & GRAFANA"
echo "# 7. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

echo "#######################################################################################################"
echo "#"
echo "# 1. UPGRADE KUBERNETES FROM 1.15 TO 1.16"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda04/upgrade_to_1.16/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 2. UPGRADE KUBERNETES FROM 1.16 TO 1.17"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda04/upgrade_to_1.17/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 3. INSTALL METALLB"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda07/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 4. INSTALL TRIDENT OPERATOR 20.10.0"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario01/2_Operator/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 5. INSTALL NAS BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario02/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 6. INSTALL & CONFIGURE PROMETHEUS & GRAFANA"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 7. UPDATE BASHRC"
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