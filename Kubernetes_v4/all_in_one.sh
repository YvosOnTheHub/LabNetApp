#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# ALL IN ONE SCRIPT THAT PERFORMS THE FOLLOWING TASKS:"
echo "#"
echo "# 1. UPGRADE TO TRIDENT OPERATOR 20.10.0"
echo "# 2. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "# 3. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "# 4. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "# 5. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

echo
echo "#######################################################################################################"
echo "#"
echo "# 1. INSTALL TRIDENT OPERATOR 20.10.0"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario01/1_Operator/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 2. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario02/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 3. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario05/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 4. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "#"
echo "#######################################################################################################"
echo

sh Scenarios/Scenario03/all_in_one.sh

echo
echo "#######################################################################################################"
echo "#"
echo "# 5. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

cp ~/.bashrc ~/.bashrc.bak
cat <<EOT >> ~/.bashrc
source <(kubectl completion bash)
complete -F __start_kubectl k

alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
bash