
yum install -y ansible-2.9.9

```
# cat <<EOT > /etc/ansible/hosts
[kubernetes]
rhel[1:3]

[kube-master]
rhel3
EOT
```

[root@rhel3 .ansible]# ansible -m ping kubernetes
rhel1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
rhel2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
rhel3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}

yum install -y svn
cd /etc/ansible/roles/
svn export https://github.com/NVIDIA/deepops/trunk/roles/netapp-trident
svn export https://github.com/mboglesby/deepops/trunk/roles/openshift
