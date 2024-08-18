#########################################################################################
# SCENARIO 14.1: ONTAP Network Management
#########################################################################################  

The configuration for the pre-existing SVM (_nassvm_) is fully open. You can mount resources from anywhere in the lab & also connect with SSH from anywhere.  

In case there is no PVC existing on the cluster, let's create one to display some content in the following example:
```bash

```

Examples ran from the host RHEL5, which is outside of the Kubernetes cluster.  
You need to start this host from LoD page.  
You can perfectly well connect through SSH:  
```bash
$ ssh -l vsadmin 192.168.0.133 volume show
Vserver   Volume       Aggregate    State      Type       Size  Available Used%
--------- ------------ ------------ ---------- ---- ---------- ---------- -----
nassvm    nassvm_root  aggr1        online     RW         20MB    17.66MB    7%
nassvm    trident_pvc_3bc9f688_aa88_40e7_8cca_da55d2575518 aggr1 online RW 1GB 1023MB  0%
2 entries were displayed.
```

You also can mount NFS resources:  
```bash
$ mkdir /mnt/non_secured
$ mount -t nfs 192.168.0.131:/trident_pvc_3bc9f688_aa88_40e7_8cca_da55d2575518 /mnt/non_secured
$ ls -la /mnt/non_secured/
ls  -la
total 4
drwx--x--x. 2 root root 4096 Jul 30 14:23 .
drwxr-xr-x. 3 root root   25 Jul 30 15:05 ..         
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

Before moving on the next steps, let's just check that we can at least ping the NFS & Mgmt interfaces we just created
```bash
$ ping 192.168.0.230
PING 192.168.0.230 (192.168.0.230) 56(84) bytes of data.
64 bytes from 192.168.0.230: icmp_seq=1 ttl=64 time=0.321 ms
64 bytes from 192.168.0.230: icmp_seq=2 ttl=64 time=0.306 ms

$ ping 192.168.0.231
PING 192.168.0.231 (192.168.0.231) 56(84) bytes of data.
64 bytes from 192.168.0.231: icmp_seq=1 ttl=64 time=0.321 ms
64 bytes from 192.168.0.231: icmp_seq=2 ttl=64 time=0.306 ms
```

## What's next

You shoud continue with:  
- [NFS Showmount](../2_NFS_Showmount): Disable the _Showmount_ capability on the storage tenant

Or go back to:  
- the [Scenario14 FrontPage](../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)