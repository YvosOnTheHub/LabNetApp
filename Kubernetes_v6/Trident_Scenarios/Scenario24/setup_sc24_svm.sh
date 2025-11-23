if [[ $(dnf list installed | grep ansible-core | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# Ansible install"
  echo "##############################################################"
  
  # test repo availability 
  REPO_URL='http://repomirror-rtp.eng.netapp.com/rhel/9server-x86_64//rhel-9-for-x86_64-appstream-rpms/repodata/repomd.xml'

  if curl -sSfI "$REPO_URL" >/dev/null 2>&1; then
    dnf install -y python-pip
  else
    wget -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
    python3 /tmp/get-pip.py
  fi

  pip install ansible-core==2.15.12 netapp-lib
  ansible-galaxy collection install netapp.ontap:==22.12.0 --ignore-certs
fi

echo
echo "##############################################"
echo "# Ansible Config"
echo "##############################################"

mkdir -p /etc/ansible
if [ -f /etc/ansible/hosts ]; then mv /etc/ansible/hosts /etc/ansible/hosts.bak; fi;
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