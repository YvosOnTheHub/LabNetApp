#!/bin/bash

# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Docker hub login"
    echo " - Parameter2: Docker hub password"
    exit 0
fi

echo
echo "#######################################################################################################"
echo "#"
echo "# ALL IN ONE SCRIPT THAT PERFORMS THE FOLLOWING TASKS:"
echo "#"
echo "# 0. LOGIN TO DOCKER HUB & PULL IMAGES"
echo "# 1. UPGRADE TO TRIDENT OPERATOR 20.10.1"
echo "# 2. INSTALL FILE (NAS/RWX) BACKENDS FOR TRIDENT"
echo "# 3. INSTALL BLOCK (iSCSI/RWO) BACKENDS FOR TRIDENT"
echo "# 4. UPDATE & CONFIGURE PROMETHEUS & GRAFANA"
echo "# 5. ENABLE POD SCHEDULING ON THE MASTER NODE" 
echo "# 6. UPDATE BASHRC"
echo "#"
echo "#######################################################################################################"
echo

echo
echo "#######################################################################################################"
echo "#"
echo "# 0. LOGIN TO DOCKER HUB & PULL IMAGES"
echo "#"
echo "#######################################################################################################"
echo

sh Addendum/Addenda09/2_Lazy_Images/pull_all_images.sh rhel1 $1 $2
sh Addendum/Addenda09/2_Lazy_Images/pull_all_images.sh rhel2 $1 $2
sh Addendum/Addenda09/2_Lazy_Images/pull_all_images.sh rhel3 $1 $2

echo
echo "#######################################################################################################"
echo "#"
echo "# 1. INSTALL TRIDENT OPERATOR 20.10.1"
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
echo "# 5. ENABLE POD SCHEDULING ON THE MASTER NODE"
echo "#"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/master-

echo
echo "#######################################################################################################"
echo "#"
echo "# 6. UPDATE BASHRC"
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