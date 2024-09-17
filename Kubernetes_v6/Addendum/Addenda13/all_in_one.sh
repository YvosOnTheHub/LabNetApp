mkdir -p /etc/ansible
if [ -f /etc/ansible/hosts ]; then mv /etc/ansible/hosts /etc/ansible/hosts.bak; fi;
cp hosts /etc/ansible/ 

ansible-playbook svm_secondary_create.yaml