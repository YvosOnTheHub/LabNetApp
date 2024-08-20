ping -c1 -W1 -q rhel4 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL4 from the LoD MyLabs page"
  echo "#################################################################"
  exit 0
fi
ping -c1 -W1 -q rhel5 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL5 from the LoD MyLabs page"
  echo "#################################################################"
  exit 0
fi

if [[ $(dnf list installed | grep ansible-core | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# Ansible install"
  echo "##############################################################"
  
  dnf install -y ansible python-pip
  pip install netapp-lib
  ansible-galaxy collection install netapp.ontap --ignore-certs
fi

echo
echo "##############################################"
echo "# Ansible Config"
echo "##############################################"

mv /etc/ansible/hosts /etc/ansible/hosts.bak
cp ../../Addendum/Addenda13/hosts /etc/ansible/ 

echo
echo "##############################################"
echo "# Secondary SVM Creation"
echo "##############################################"

ansible-playbook ../../Addendum/Addenda13/svm_secondary_create.yaml

echo
echo "##############################################"
echo "# SVM Peering"
echo "##############################################"

ansible-playbook svm_peering.yaml

echo
echo "#####################################################"
echo "# Copy second K8S cluster creation script to RHEL5"
echo "#####################################################"

curl -s --insecure --user root:Netapp1! -T ../../Addendum/Addenda12/all_in_one.sh sftp://rhel5/root/

echo
echo "#####################################################"
echo "# Launch second cluster setup"
echo "#####################################################"

sshpass -p Netapp1! ssh -o "StrictHostKeyChecking no" root@rhel5 sh all_in_one.sh