#########################################################################################
# SCENARIO 13: ONTAP Snapshots accessibility & visibility
#########################################################################################  

Snapshots available in ONTAP can be visible and accessed depending on 3 parameters:
- NFS version: NFSv3 vs NFSv4
- Trident parameter: snapshotDir
- ONTAP SVM parameter to hide snapshots: v3-hide-snapshot

Let's see in this chapter how all these paremeters work together & what behavior we will observe.

**TL;DR: BEGINNING**  
**this table summarized my findings:**

| Config | NFS Version | Trident SnapshotDir | SVM v3-hide-snapshot | .snapshot accessible | .snapshot visible
| :--- | :---: | :---: | :---: | :---: | :---: |
| [Config1](#config1) | NFSv4 | true | N/A | :white_check_mark: | :ghost: |
| [Config2](#config2) | NFSv4 | false | N/A | :stop_sign: | :stop_sign: |
| [Config3](#config3) | NFSv3 | true | disabled | :white_check_mark: | :white_check_mark: |
| [Config4](#config4) | NFSv3 | false | disabled | :stop_sign: | :stop_sign: |
| [Config5](#config5) | NFSv3 | true | enabled | :white_check_mark: | :ghost: |
| [Config6](#config6) | NFSv3 | false | enabled | :stop_sign: | :stop_sign: |

**.snapshot visible** :ghost: = even though the .snapshot directory is accessible, you cannot see it

To complete this summary, some extra comments:
- Changing the SVM parameter does not affect existing **mounted** volumes  
- Changing a Trident backend does not affect existing volumes  
- the NFS version can be set in the Trident backend, in the storage class or for the whole worker node (/etc/nfsmount.conf & _NFSMount_Global_Options_ parameter)  

**IMPORTANT**:  
Some applications apply specific rights recursively to all sub-folders of a PVC, which includes the _.snapshot_ folder...  
However, being Read-only, changing rights will fail and the pod will not start. When using NFSv3, make sure to take this into account.    
Here is an example of what to expect with a MySQL pod:  
```bash
$ kubectl get -n wp po,pvc                                   
NAME                                  READY   STATUS             RESTARTS      AGE
pod/wordpress-mysql-b67bbf64c-5gsx5   0/1     CrashLoopBackOff   3 (38s ago)   106s

NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mysql-pvc   Bound    pvc-99c008a1-372b-4a8e-a978-485aa047ef0c   100Gi      RWO            storage-class-nfs   <unset>                 106s

$ kubectl logs -n wp pod/wordpress-mysql-b67bbf64c-5gsx5
2025-09-18 07:02:21+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.43-1.el9 started.
chown: changing ownership of '/var/lib/mysql/.snapshot': Read-only file system
```
**TL;DR: END**

For each configuration, we will do the following:
- create a PVC mounted by a Busybox POD in a dedicated namespace  
- check the NFS version used to mount the volume
- create a snapshot through REST API
- check if we can list the snapshots
- check if we can access the .snapshot directory

## A. Chapter setup

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario13_busybox_pull_images.sh* to pull images utilized in this scenario if needed:  
```bash
sh scenario13_busybox_pull_images.sh
```

We are going to create 4 new Trident backends, alongside their corresponding storage class.  
No need to create 2 extra backends for the 2 last configs, as the difference is in the ONTAP configuration.  
The _sc13_access_visi_setup.yaml_ can be used to create all 8 objects in Kubernetes:  
```bash
$ kubectl create -f sc13_access_visi_setup.yaml
tridentbackendconfig.trident.netapp.io/backend-sc13-config1 created
storageclass.storage.k8s.io/config1 created
tridentbackendconfig.trident.netapp.io/backend-sc13-config2 created
storageclass.storage.k8s.io/config2 created
tridentbackendconfig.trident.netapp.io/backend-sc13-config3 created
storageclass.storage.k8s.io/config3 created
tridentbackendconfig.trident.netapp.io/backend-sc13-config4 created
storageclass.storage.k8s.io/config4 created
```

Note that the hosts of this lab, which runs RHEL 9.3, defaults to NFSv4.2.  

<a name="config1"></a>
## B. Testing Config1

The _config1_ backend contains the parameter _snapshotDir: 'true'_, which gives access to the .snapshot directory.    

The _sc13-config1.yaml_ file will create a PVC & a POD in a new namespace called _config1_:
```bash
$ kubectl create -f sc13-config1.yaml
namespace/config1 created
persistentvolumeclaim/pvc1 created
pod/pod1 created

$ kubectl get -n config1 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod1   1/1     Running   0          15m   192.168.28.67   rhel2   <none>           <none>

$ kubectl get -n config1 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc1   Bound    pvc-434edd21-3ff7-4b8a-bde7-c9a07bfd275b   1Gi        RWX            config1        <unset>                 15m
```
As the pod runs on the node RHEL2, let's see what version of NFS is used to mount the volume:
```bash
$ ssh -o "StrictHostKeyChecking no" root@rhel2 -t "mount | grep pvc-434edd21-3ff7-4b8a-bde7-c9a07bfd275b"
192.168.0.131:/cfg1_pvc_434edd21_3ff7_4b8a_bde7_c9a07bfd275b on /var/lib/kubelet/pods/eca56acd-4470-4831-8483-890160eebdab/volumes/kubernetes.io~csi/pvc-434edd21-3ff7-4b8a-bde7-c9a07bfd275b/mount type nfs4 (rw,relatime,vers=4.2,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.62,local_lock=none,addr=192.168.0.131)
```
There you go, you can see that NFSv4.1 is used to mount the PVC.  
Let's create a snapshot (using the _sc13-config1-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config1-snapshot-create.sh

$ kubectl exec -n config1 pod1 -- ls -la /data
total 4
drwxrwxrwx    2 99       99            4096 Jul 30 19:03 .
drwxr-xr-x    1 root     root            29 Jul 30 19:03 ..

$ kubectl exec -n config1 pod1 -- ls -la /data/.snapshot
total 12
drwxrwxrwx    3 root     root          4096 Jul 30 09:45 .
drwxrwxrwx    2 root     root          4096 Jul 30 08:59 ..
drwxrwxrwx    2 root     root          4096 Jul 30 08:59 scenario13
```

We have verified here that in the context of NFSv4: 
- the .snapshot directory is hidden (because of the protocol version)
- the .snapshot directory is accessible (because of the _snapshotDir: 'true'_ parameter in the Trident backend)

<a name="config2"></a>
## C. Testing Config2

The _config2_ backend does not contain the parameter _snapshotDir_ which default to _false_.  

The _sc13-config2.yaml_ file will create a PVC & a POD in a new namespace called _config2_:
```bash
$ kubectl create -f sc13-config2.yaml
namespace/config2 created
persistentvolumeclaim/pvc2 created
pod/pod2 created

$ kubectl get -n config2 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE     IP               NODE    NOMINATED NODE   READINESS GATES
pod2   1/1     Running   0          2m11s   192.168.28.66    rhel2   <none>           <none>

$ kubectl get -n config2 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc2   Bound    pvc-17d10f09-7efc-4624-8a1d-3eb5185eeb91   1Gi        RWX            config2        <unset>                 24s
```
As the pod runs on the node RHEL2, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel2 -t "mount | grep pvc-17d10f09-7efc-4624-8a1d-3eb5185eeb91"
192.168.0.131:/cfg2_pvc_17d10f09_7efc_4624_8a1d_3eb5185eeb91 on /var/lib/kubelet/pods/7e6b6952-3796-466f-acc9-5c5548090e89/volumes/kubernetes.io~csi/pvc-17d10f09-7efc-4624-8a1d-3eb5185eeb91/mount type nfs4 (rw,relatime,vers=4.2,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.62,local_lock=none,addr=192.168.0.131)
```
There you go, you can see that NFSv4.1 is used to mount the PVC.  
Let's create a snapshot (using the _sc13-config2-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config2-snapshot-create.sh

$ kubectl exec -n config2 pod2 -- ls -la /data
total 4
drwxrwxrwx    2 99       99            4096 Aug 27 19:25 .
drwxr-xr-x    1 root     root            29 Aug 27 19:26 ..

$ kubectl exec -n config2 pod2 -- ls -la /data/.snapshot
ls: /data/.snapshot: No such file or directory
command terminated with exit code 1
```

We have verified here that in the context of NFSv4, the .snapshot directory is not accessible and is hidden, thanks to the snapshotDir:false parameter.

<a name="config3"></a>
## D. Testing Config3

We are now going to test various configurations, using NFSv3.  
The version of NFS is set in the Trident backend. Note that it could also be set in the storage class, with the parameter _mountOptions_.  

The _config3_ backend contains the parameter _snapshotDir: 'true'_, which gives access to the .snapshot directory.  

The _sc13-config3.yaml_ file will create a PVC & a POD in a new namespace called _config3_:
```bash
$ kubectl create -f sc13-config3.yaml
namespace/config3 created
persistentvolumeclaim/pvc3 created
pod/pod3 created

$ kubectl get -n config3 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod3   1/1     Running   0          23s   192.168.28.65   rhel2   <none>           <none>

$ kubectl get -n config3 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc3   Bound    pvc-437b6e27-6e0d-4b83-8f44-3b6ad3454ec5   1Gi        RWX            config3        <unset>                 37s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel2 -t "mount | grep pvc-437b6e27-6e0d-4b83-8f44-3b6ad3454ec5"
192.168.0.131:/cfg3_pvc_437b6e27_6e0d_4b83_8f44_3b6ad3454ec5 on /var/lib/kubelet/pods/26ae2023-9d01-4e8d-9144-b8fd1b8d71d7/volumes/kubernetes.io~csi/pvc-437b6e27-6e0d-4b83-8f44-3b6ad3454ec5/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.131,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.131)
```
As expected, we are now using NFSv3.  
Let's create a snapshot (using the _sc13-config3-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config3-snapshot-create.sh

$ kubectl exec -n config3 pod3 -- ls -la /data
total 8
drwxrwxrwx    2 root     root          4096 Aug 27 19:30 .
drwxr-xr-x    1 root     root            29 Aug 27 19:30 ..
drwxrwxrwx    3 root     root          4096 Aug 27 19:32 .snapshot

$ kubectl exec -n config3 pod3 -- ls -la /data/.snapshot
total 12
drwxrwxrwx    3 root     root          4096 Aug 27 19:32 .
drwxrwxrwx    2 root     root          4096 Aug 27 19:30 ..
drwxrwxrwx    2 root     root          4096 Aug 27 19:30 scenario13
```

We have verified here that in the context of NFSv3: 
- the .snapshot directory is visible (parameter _v3-hide-snapshot_ in the SVM is left to its defaut value: _disabled_)
- the .snapshot directory is accessible (because of the _snapshotDir: 'true'_ parameter in the Trident backend)

<a name="config4"></a>
## E. Testing Config4

The _config4_ backend does not contain the parameter _snapshotDir_ which defaults to _false_.  

The _sc13-config4.yaml_ file will create a PVC & a POD in a new namespace called _config4_:
```bash
$ kubectl create -f sc13-config4.yaml
namespace/config4 created
persistentvolumeclaim/pvc4 created
pod/pod4 created

$ kubectl get -n config4 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod4   1/1     Running   0          26s   192.168.28.78   rhel2   <none>           <none>

$ kubectl get -n config4 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc4   Bound    pvc-53d363d5-01b1-4a92-8807-c52bdfab9985   1Gi        RWX            config4        <unset>                 14s
```
As the pod runs on the node RHEL2, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel2 -t "mount | grep pvc-53d363d5-01b1-4a92-8807-c52bdfab9985"
192.168.0.131:/cfg4_pvc_53d363d5_01b1_4a92_8807_c52bdfab9985 on /var/lib/kubelet/pods/395498c9-54bc-4614-9c70-6fda314eb5e8/volumes/kubernetes.io~csi/pvc-53d363d5-01b1-4a92-8807-c52bdfab9985/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.131,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.131)
```
As expected, we are using NFSv3.  
Let's create a snapshot (using the _sc13-config4-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config4-snapshot-create.sh

$ kubectl exec -n config4 pod4 -- ls -la /data
total 4
drwxrwxrwx    2 root     root          4096 Aug 27 19:34 .
drwxr-xr-x    1 root     root            29 Aug 27 19:35 ..

$ kubectl exec -n config4 pod4 -- ls -la /data/.snapshot
ls: /data/.snapshot: No such file or directory
command terminated with exit code 1
```

We have verified here that in the context of NFSv3, the .snapshot directory is not accessible and is hidden, thanks to the _snapshotDir:false_ parameter.

<a name="config5"></a>
## F. Testing Config5

Config5 is a copy of Config3 from a Trident perspective.  
However, the SVM parameter to hide snapshots has been enabled, as follows (connect with Putty to _cluster1_):
```bash
cluster1::> nfs modify -vserver nassvm -v3-hide-snapshot enabled
```

The _config3_ backend contains the parameter _snapshotDir: 'true'_, which gives access to the .snapshot directory.  

The _sc13-config5.yaml_ file will create a PVC (using the backend _config3_) & a POD in a new namespace called _config5_:
```bash
$ kubectl create -f sc13-config5.yaml
namespace/config5 created
persistentvolumeclaim/pvc5 created
pod/pod5 created

$ kubectl get -n config5 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod5   1/1     Running   0          15s   192.168.26.33   rhel1   <none>           <none>

$ kubectl get -n config5 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc5   Bound    pvc-23e00119-d4fa-48a6-b64a-1109863a465a   1Gi        RWX            config3        <unset>                 29s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep pvc-23e00119-d4fa-48a6-b64a-1109863a465a"
192.168.0.131:/cfg3_pvc_23e00119_d4fa_48a6_b64a_1109863a465a on /var/lib/kubelet/pods/c4ab29f6-3e6a-46b2-9f15-a78b560ca7d8/volumes/kubernetes.io~csi/pvc-23e00119-d4fa-48a6-b64a-1109863a465a/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.131,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.131)
```
As expected, we are using NFSv3.  
Let's create a snapshot (using the _sc13-config5-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config5-snapshot-create.sh

$ kubectl exec -n config5 pod5 -- ls -la /data
total 4
drwxrwxrwx    2 root     root          4096 Aug 27 19:58 .
drwxr-xr-x    1 root     root            29 Aug 27 19:58 ..

$ kubectl exec -n config5 pod5 -- ls -la /data/.snapshot
total 12
drwxrwxrwx    3 root     root          4096 Aug 27 19:59 .
drwxrwxrwx    2 root     root          4096 Aug 27 19:58 ..
drwxrwxrwx    2 root     root          4096 Aug 27 19:58 scenario13
```

We have proved here that in the context of NFSv3: 
- the .snapshot directory is hidden (because of the _v3-hide-snapshot:enabled_ parameter set in the SVM)
- the .snapshot directory is accessible (because of the _snapshotDir: 'true'_ parameter in the Trident backend)

<a name="config6"></a>
## G. Testing Config6

The difference with the _config5_ backend relies on the parameter _snapshotDir_ not explicitly set, which defaults to _false_. 

The _sc13-config6.yaml_ file will create a PVC (using the backend _config4_) & a POD in a new namespace called _config6_:
```bash
$ kubectl create -f sc13-config6.yaml
namespace/config6 created
persistentvolumeclaim/pvc6 created
pod/pod5 created

$ kubectl get -n config6 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod6   1/1     Running   0          9s    192.168.28.74   rhel2   <none>           <none>

$ kubectl get -n config6 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc6   Bound    pvc-3357445a-f500-40db-8c25-fc31db97cb53   1Gi        RWX            config4        <unset>                 26s
```
As the pod runs on the node RHEL2, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel2 -t "mount | grep pvc-3357445a-f500-40db-8c25-fc31db97cb53"
192.168.0.131:/cfg4_pvc_3357445a_f500_40db_8c25_fc31db97cb53 on /var/lib/kubelet/pods/3a61a56f-1212-4040-8f80-dd0ddc64d52f/volumes/kubernetes.io~csi/pvc-3357445a-f500-40db-8c25-fc31db97cb53/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.131,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.131)
```
As expected, we are using NFSv3.  
Let's create a snapshot (using the _sc13-config6-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config6-snapshot-create.sh

$ kubectl exec -n config6 pod6 -- ls -la /data
total 4
drwxrwxrwx    2 root     root          4096 Aug 28 07:06 .
drwxr-xr-x    1 root     root            29 Aug 28 07:07 ..

$ kubectl exec -n config6 pod6 -- ls -la /data/.snapshot
ls: /data/.snapshot: No such file or directory
command terminated with exit code 1
```
We have verified here that in the context of NFSv3, the .snapshot directory is not accessible and is hidden, thanks to the _snapshotDir:false_ parameter.


## H. Clean up

Unless you want to run some extra tests, you can delete all 6 namespaces used here, as well as the Trident configuration:
```bash
$ kubectl get ns -o name | grep config[1-6] | xargs kubectl delete
namespace "config1" deleted
namespace "config2" deleted
namespace "config3" deleted
namespace "config4" deleted
namespace "config5" deleted
namespace "config6" deleted

$ kubectl delete -f sc13_access_visi_setup.yaml
secret "secret-sc13" deleted
tridentbackendconfig.trident.netapp.io "backend-sc13-config1" deleted
storageclass.storage.k8s.io "config1" deleted
tridentbackendconfig.trident.netapp.io "backend-sc13-config2" deleted
storageclass.storage.k8s.io "config2" deleted
tridentbackendconfig.trident.netapp.io "backend-sc13-config3" deleted
storageclass.storage.k8s.io "config3" deleted
tridentbackendconfig.trident.netapp.io "backend-sc13-config4" deleted
storageclass.storage.k8s.io "config4" deleted
```
You can also modify the SVM in order to bring it back to its previous configuration with regards to the v3-hide-snapshot parameter:
```bash
cluster1::> nfs modify -vserver nassvm -v3-hide-snapshot disabled
```
