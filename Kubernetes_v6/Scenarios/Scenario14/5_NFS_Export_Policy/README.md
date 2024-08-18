#########################################################################################
# SCENARIO 14.3: Restrict the SVM export policy
#########################################################################################  

One rule (192.168.0.0/24) has been created for the _default_ export policy.  
That means that you can mount '/' on a host outside of the Kubernetes cluster.  
You are not going to be able to access these volumes with the configuration we are putting in place. However, you can still see their names!  
Once the NAS backend is created (with Dynamic Export Policy), I would **strongly** recommend to modify the export policy assigned to the tenant root volume, with the one dynamically managed by Trident.  
That way, you add an extra layer of security.  

Let's look at what we can mount on a host outside of the Kubernetes cluster (_rhel5_):  
```bash
$ mkdir /mnt/secured
$ mount -t nfs 192.168.0.231:/ /mnt/secured/
$ ls -la /mnt/secured/
total 8
drwxr-xr-x. 3 root root 4096 Jul 30 16:19 .
drwxr-xr-x. 4 root root   40 Jul 30 16:27 ..
drwxrwxrwx. 2 root root 4096 Jul 30 16:19 .snapshot
$ umount /mnt/test
```

We can still see the content of the SVM!  
If PVC were present, you would see their name.  

As said in the first part of this scenario, the root volume is exported with a policy that is too open (192.168.0.0/24 in this case).  
That is simply because at the time of the storage tenant creation, Trident had not yet been configured.  
We should definitely assign it the policy created by Trident, which is dynamic & will evolve alongside the Kubernetes cluster.  

Another Ansible playbook will be used to perform this task (assuming the SVM only has one export policy dynamically managed by Trident).  
```bash
$ ansible-playbook svm_secured_export_policy.yaml
PLAY [Set Export Policy on Tenant Root]
TASK [Gathering Facts]
TASK [Gather Tenant Export Policy information]
TASK [Modify root Export Policy]
PLAY RECAP
localhost                  : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Protection applied!  
Let's try again to mount the storage tenant root volume on _rhel5_:  
```bash
$ mount -t nfs 192.168.0.231:/ /mnt/test/
mount.nfs: access denied by server while mounting 192.168.0.231:/
```

DONE !