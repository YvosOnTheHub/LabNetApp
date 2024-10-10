#########################################################################################
# ADDENDA 4: Install Ansible on RHEL3
#########################################################################################

**GOAL:**  
Ansible can be useful in some cases. Let's see how to install it on the control plane.  

We first need to install the Python package manager, followed by Ansible and the NetApp python library.  
```bash
dnf install -y python-pip
pip install ansible-core==2.15.12 netapp-lib
```

Last, we will install the NetApp ONTAP Collection from the Ansible Galaxy.  
```bash
$ ansible-galaxy collection install netapp.ontap:==22.12.0 --ignore-certs
Process install dependency map
Starting collection install process
Installing 'netapp.ontap:22.12.0' to '/root/.ansible/collections/ansible_collections/netapp/ontap'
netapp.ontap:22.12.0 was installed successfully
```

Now that Ansible is installed, let's configure the host file  
```bash
$ mkdir /etc/ansible
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
```
We can now test connectivity with no issues.  
```bash
$ ansible -m ping kubernetes
rhel2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
rhel1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
rhel3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?