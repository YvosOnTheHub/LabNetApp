#########################################################################################
# SCENARIO 14.1: ONTAP Network Management
#########################################################################################  

The configuration for the pre-existing SVM (_nassvm_) is fully open. You can theoretically mount resources from anywhere in the lab & also connect with SSH from anywhere.  

Mounting a NFS volume is controlled in ONTAP by the export policy associated to it.  
With Trident, there are 2 possibilities:  
- use a pre-defined export policy, with the Trident backend parameter _exportPolicy_
- let Trident manage export policies by setting the Dynamic export policy feature (check [scenario 12](../../Scenario12/) for more details) 

Setting the Dynamic Export Policy feature is already secured by design.  
Trident adds to its managed policies rules containing the IP address of the worker nodes where PVCs are mounted to pods.  
Other worker nodes (not mounting the PVC) or other hosts cannot access that ONTAP volume.  
More, if the pod changes worker node, Trident will update the export policy.

With manual export policy management, the rule created by the storage admin may be too open.  

As the ONTAP-NAS-ECONOMY backend is not configured with Dyn Export Policy, the following will be done against the corresponding storage class:  

In case there is no PVC existing on the cluster, let's create one to display some content in the following example:
```bash
$ cat << EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: storage-class-nas-economy
EOF
persistentvolumeclaim/test created
```

Examples ran from the host RHEL5, which is outside of the Kubernetes cluster.  
You need to start this host from LoD page if not done already.  
You can perfectly well connect through SSH:  
```bash
$ ssh -l vsadmin 192.168.0.133 qtree show

Vserver    Volume        Qtree        Style        Oplocks   Status
---------- ------------- ------------ ------------ --------- --------
nassvm     nassvm_root   ""           unix         enable    normal
nassvm     trident_qtree_pool_nas_eco_BGKNSUVJEU "" unix enable normal
nassvm     trident_qtree_pool_nas_eco_BGKNSUVJEU nas_eco_pvc_1214d05a_873b_4596_afd2_7930495627e5 unix enable normal
3 entries were displayed.
```

You also can mount NFS resources on this host as the default export policy is configured with 0.0.0.0/0, hence open to the world :  
```bash
$ mkdir /mnt/non_secured
$ mount -t nfs 192.168.0.131:/trident_pvc_2db4122d_c95b_4d2e_aca7_d8d419f98799 /mnt/non_secured
$ mount -t nfs 192.168.0.131:/trident_qtree_pool_nas_eco_BGKNSUVJEU/nas_eco_pvc_1214d05a_873b_4596_afd2_7930495627e5 /mnt/non_secured
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