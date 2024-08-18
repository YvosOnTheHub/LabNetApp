#########################################################################################
# ADDENDA 4: Install Ansible on RHEL3
#########################################################################################

**GOAL:**  
Ansible can be useful in some cases. Let's see how to install it on the control plane.  

Super easy ...  
```bash
yum install -y ansible
```

In order to use NetApp modules, we need to install the NetApp python library . 
```bash
yum install -y python-pip
pip install netapp-lib
```

Last, we will install the NetApp ONTAP Collection from the Ansible Galaxy.  
```bash
$ ansible-galaxy collection install netapp.ontap --ignore-certs
Process install dependency map
Starting collection install process
Installing 'netapp.ontap:22.11.0' to '/root/.ansible/collections/ansible_collections/netapp/ontap'
netapp.ontap:22.11.0 was installed successfully
```

Now that Ansible is installed, let's configure the host file  
```bash
$ cat <<EOT > /etc/ansible/hosts
[kubernetes]
rhel[1:3]

[kube-master]
rhel3
EOT
```

We will now make sure that Ansible works & each node can be used.  
Ansible will use SSH to test connectivity. We first need to exchange keys between nodes. Enter the following commands and keep the default values
```bash
ssh-keygen
ssh-copy-id root@192.168.0.61
ssh-copy-id root@192.168.0.62
ssh-copy-id root@192.168.0.63
```
We can now test connectivity with no issues.  
```bash
$ ansible -m ping kubernetes
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

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?