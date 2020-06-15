#########################################################################################
# ADDENDA 6: Install Ansible on RHEL3
#########################################################################################

**GOAL:**  
Ansible can be useful in some cases. Let's see how to install it on the master node.  


## A. Install Ansible

Super easy ...
```
# yum install -y ansible-2.9.9
```

Now that Ansible is installed, let's configure the host file
```
# cat <<EOT > /etc/ansible/hosts
[kubernetes]
rhel[1:3]

[kube-master]
rhel3
EOT
```

We will now make sure that Ansible works & each node can be used.
```
# ansible -m ping kubernetes
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
```

## B. Install SVN

Sometimes, you dont want to copy a full GitHub repository, but only a subset of it...  
However the 'git' command line does not offer this possibility. The 'svn' command line can help you here.
```
# yum install -y svn
```
In order to copy a subset of a repository, you need to modify the URL, by replacing "tree/master" with "trunk"
Example with https://github.com/NVIDIA/deepops/tree/master/roles/netapp-trident
```
# cd /etc/ansible/roles/
# svn export https://github.com/NVIDIA/deepops/trunk/roles/netapp-trident
```


## C. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?