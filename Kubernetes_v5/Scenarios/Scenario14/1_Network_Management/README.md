#########################################################################################
# SCENARIO 14.1: ONTAP Network Management
#########################################################################################  

The configuration for the pre-existing SVM (_nfs_svm_) is fully open. You can mount resources from anywhere in the lab & also connect with SSH from anywhere.  

Examples ran from the host RHEL6, which is outside of the Kubernetes cluster.  
You can perfectly well connect through SSH:

```bash
$ ssh -l vsadmin 192.168.0.135 volume show
Vserver   Volume              Aggregate    State      Type       Size  Available Used%
--------- ------------        ------------ ---------- ---- ---------- ---------- -----
nfs_svm   nfs_svm_root        aggr1        online     RW         20MB    17.10MB   10%
nfs_svm   registry            aggr1        online     RW         20GB    18.93GB    0%
nfs_svm   vol_import_manage   aggr1        online     RW          2GB     1.90GB    0%
nfs_svm   vol_import_nomanage aggr1        online     RW          2GB     1.90GB    0%
nfs_svm   www                 aggr1        online     RW          5GB     4.75GB    0%
5 entries were displayed.
```

You also can mount NFS resources:

```bash
$ mkdir /mnt/non_secured
$ mount -t nfs 192.168.0.132:/registry /mnt/non_secured
$ ls /mnt/non_secured/
docker
$ umount /mnt/non_secured
```

Let's configure our new SVM to restrict:

- Management tasks to HTTP only & to Kubernetes hosts only
- Data paths to Kubernetes hosts only

We will use another ansible playbook to create these new network objects:

```bash
$ ansible-playbook svm_secured_network.yaml
PLAY [Secured SVM Network Management]
TASK [Gathering Facts]
TASK [Create Specific User]
TASK [Create Service Policy for Management]
TASK [Create Service Policy for NFS]
TASK [Create Service Policy for iSCSI]
TASK [Create Mgmt Interface]
TASK [Create NFS Interface]
TASK [Create iSCSI Interface]
PLAY RECAP
localhost                  : ok=10    changed=9    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

With this configuration:

- NFS mounts can only be done through one LIF & only on the Kubernetes nodes
- iSCSI LUNs can only be done via the iSCSI LIF & only on the Kubernetes nodes
- SVM Management is restricted to API & only on the Kubernetes nodes  

**One important thing to notice:**  
One rule (192.168.0.0/24) has been created for the _default_ export policy.  
That means that you can mount '/' on a host outside of the Kubernetes cluster.  
You are not going to be able to access these volumes with the configuration we are putting in place. However, you can still see their names!  
Once the NAS backend is created (with Dynamic Export Policy), I would **strongly** recommend to modify the export policy assigned to the tenant root volume, with the one dynamically managed by Trident.  
That way, you add an extra layer of security.  

Before moving on the next steps, let's just check that we can at least ping the NFS & Mgmt interfaces we just created
```bash
$ ping 192.168.0.210
PING 192.168.0.210 (192.168.0.210) 56(84) bytes of data.
64 bytes from 192.168.0.210: icmp_seq=1 ttl=64 time=0.321 ms
64 bytes from 192.168.0.210: icmp_seq=2 ttl=64 time=0.306 ms

$ ping 192.168.0.211
PING 192.168.0.211 (192.168.0.211) 56(84) bytes of data.
64 bytes from 192.168.0.211: icmp_seq=1 ttl=64 time=0.321 ms
64 bytes from 192.168.0.211: icmp_seq=2 ttl=64 time=0.306 ms
```

## What's next

You shoud continue with:

- [NFS Showmount](../2_NFS_Showmount): Disable the _Showmount_ capability on the storage tenant

Or go back to:

- the [Scenario14 FrontPage](../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)