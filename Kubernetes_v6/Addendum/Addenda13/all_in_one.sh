mv /etc/ansible/hosts /etc/ansible/hosts.bak
cp hosts /etc/ansible/ 

ansible-playbook svm_secondary_create.yaml