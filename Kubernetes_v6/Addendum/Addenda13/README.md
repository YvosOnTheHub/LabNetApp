#########################################################################################
# Addenda 13: Create a new SVM
#########################################################################################  

You may need an extra SVM to demo some Trident features (especially the SnapMirror support introduced in 24.06.1).  
We will use Ansible to create this new storage tenant.  
Ansible should already be deployed on RHEL3. Follow [Addenda04](../Addenda04/) to install it if not done yet.  

We also need to setup the inventory for this scenario. It will contain various global variables.  
You just need to copy the hosts file from this scenario into the /etc/ansible folder.  
```bash
mv /etc/ansible/hosts /etc/ansible/hosts.bak
cp hosts /etc/ansible/ 
```
Let's now create a new SVM called **svm_secondary**.  
```bash
$ ansible-playbook svm_secondary_create.yaml
PLAY [Secondary SVM Creation] 
TASK [Gathering Facts] 
TASK [Create SVM] 
TASK [Create Specific User] 
TASK [Enable NFS] 
TASK [Create ExportPolicyRule for the default policy] 
TASK [Enable iSCSI] 
TASK [Create Service Policy for Management (Core)] 
TASK [Create Service Policy for Management (HTTPS)] 
TASK [Create Service Policy for NFS (Core)] 
TASK [Create Service Policy for NFS (Data)] 
TASK [Create Service Policy for iSCSI (Core)] 
TASK [Create Service Policy for iSCSI (Data)] 
TASK [Create Mgmt Interface] 
TASK [Create NFS Interface] 
TASK [Create iSCSI Interface] 
PLAY RECAP 
localhost                  : ok=15   changed=14   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

& just like that, you have a new SVM available.