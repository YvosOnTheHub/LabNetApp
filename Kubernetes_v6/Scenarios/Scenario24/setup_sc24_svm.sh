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