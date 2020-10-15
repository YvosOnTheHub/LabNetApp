#########################################################################################
# SCENARIO 15.1: ONTAP Network Management
#########################################################################################  

The configuration for the pre-existing SVM is fully open. You can mount resources from anywhere in the lab & also connect with SSH from anywhere.  

Examples ran from the host RHEL6, which is outside of the Kubernetes cluster.  
You can perfectly well connect through SSH:

```bash
$ ssh -l vsadmin 192.168.0.135 volume show
Vserver   Volume       Aggregate    State      Type       Size  Available Used%
--------- ------------ ------------ ---------- ---- ---------- ---------- -----
svm1      registry     aggr1        online     RW         20GB    18.93GB    0%
svm1      svm1_root    aggr1        online     RW         20MB    17.10MB   10%
svm1      vol_import_manage aggr1   online     RW          2GB     1.90GB    0%
svm1      vol_import_nomanage aggr1 online     RW          2GB     1.90GB    0%
svm1      www          aggr1        online     RW          5GB     4.75GB    0%
5 entries were displayed.
```

You also can mount NFS resources:

```bash
$ mkdir /mnt/non_secured
$ mount -t nfs 192.168.0.135:/registry non_secured
$ ls non_secured/
docker
$ umount /mnt/non_secured
```

Let's configure our new SVM to restrict:

- Management tasks to HTTP only & to Kubernetes hosts only
- Data paths to Kubernetes hosts only

############### IMAGE

We will use another ansible playbook to create these new network objects:

```bash
$ ansible-playbook svm_secured_network.yaml
PLAY [Secured SVM User Management]
TASK [Gathering Facts]
TASK [Create Specific User]
TASK [Create Service Policy for Management]
TASK [Create Service Policy for NFS]
TASK [Create Service Policy for iSCSI]
TASK [Create Mgmt Interface]
TASK [Create NFS Interface]
TASK [Create iSCSI Interface]
PLAY RECAP
localhost                  : ok=7    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```