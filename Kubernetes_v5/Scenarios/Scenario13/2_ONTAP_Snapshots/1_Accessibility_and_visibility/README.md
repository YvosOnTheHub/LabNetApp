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

.snapshot visible :ghost: = even though the .snapshot directory is accessible, you cannot see it

To complete this summary, some extra comments:
- Changing the SVM parameter does not affect existing **mounted** volumes  
- Changing a Trident backend does not affect existing volumes  
- the NFS version can be set in the Trident backend, in the storage class or for the whole worker node (/etc/nfsmount.conf & _NFSMount_Global_Options_ parameter)  

**TL;DR: END**

For each configuration, we will do the following:
- create a PVC mounted by a Busybox POD in a dedicated namespace  
- check the NFS version used to mount the volume
- create a snapshot through REST API
- check if we can list the snapshots
- check if we can access the .snapshot directory

## A. Chapter setup

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

Note that the hosts of this lab, which runs RHEL 7.5, defaults to NFSv4.1.  

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
NAME   READY   STATUS    RESTARTS   AGE     IP              NODE    NOMINATED NODE   READINESS GATES
pod1   1/1     Running   0          3m45s   192.168.24.42   rhel1   <none>           <none>

$ kubectl get -n config1 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc1   Bound    pvc-2286652d-5662-4279-95bd-134199bb9365   1Gi        RWX            config1        3m49s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
$ ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep pvc-2286652d-5662-4279-95bd-134199bb9365"
192.168.0.132:/cfg1_pvc_2286652d_5662_4279_95bd_134199bb9365 on /var/lib/kubelet/pods/b826527b-cd34-45fa-97ef-352f54e36c2f/volumes/kubernetes.io~csi/pvc-2286652d-5662-4279-95bd-134199bb9365/mount type nfs4 (rw,relatime,vers=4.1,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.61,local_lock=none,addr=192.168.0.132)
```
There you go, you can see that NFSv4.1 is used to mount the PVC.  
Let's create a snapshot (using the _sc13-config1-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config1-snapshot-create.sh

$ kubectl exec -n config1 pod1 -- ls -la /data
total 4
drwxrwxrwx    2 99       99            4096 Aug 27 19:03 .
drwxr-xr-x    1 root     root            29 Aug 27 19:03 ..

$ kubectl exec -n config1 pod1 -- ls -la /data/.snapshot
total 12
drwxrwxrwx    3 99       99            4096 Aug 27 19:19 .
drwxrwxrwx    2 99       99            4096 Aug 27 19:03 ..
drwxrwxrwx    2 99       99            4096 Aug 27 19:03 scenario13
```

We have verified here that in the context of NFSv4: 
- the .snapshot directory is hidden (because of the protocol version)
- the .snapshot directory is accessible (because of the _snapshotDir: 'true'_ parameter in the Trident backend)

<a name="config2"></a>
## C. Testing Config2

The _config2_ backend does not contain the parameter _snapshotDir_ which default to _false_.  

The _sc13-config2.yaml_ file will create a PVC & a POD in a new namespace called _config2_:
```bash
$ kubectl create -f config2.yaml
namespace/config2 created
persistentvolumeclaim/pvc2 created
pod/pod2 created

$ kubectl get -n config2 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE     IP               NODE    NOMINATED NODE   READINESS GATES
pod2   1/1     Running   0          2m11s   192.168.24.210   rhel2   <none>           <none>

$ kubectl get -n config2 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc2   Bound    pvc-c27ca958-04bc-4d3b-bf22-d72f07b02192   1Gi        RWX            config2        2m14s
```
As the pod runs on the node RHEL2, let's see what version of NFS is used to mount the volume:
```bash
$  ssh -o "StrictHostKeyChecking no" root@rhel2 -t "mount | grep pvc-c27ca958-04bc-4d3b-bf22-d72f07b02192"
192.168.0.132:/cfg2_pvc_c27ca958_04bc_4d3b_bf22_d72f07b02192 on /var/lib/kubelet/pods/4788ac4c-f8f9-40d7-9b97-1706b85d6c12/volumes/kubernetes.io~csi/pvc-c27ca958-04bc-4d3b-bf22-d72f07b02192/mount type nfs4 (rw,relatime,vers=4.1,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.62,local_lock=none,addr=192.168.0.132)
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
$ kubectl create -f config3.yaml
namespace/config3 created
persistentvolumeclaim/pvc3 created
pod/pod3 created

$ kubectl get -n config3 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod3   1/1     Running   0          28s   192.168.24.18   rhel1   <none>           <none>

$ kubectl get -n config3 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc3   Bound    pvc-b7355ed0-45a7-48bd-896f-c06c2cf7f7c7   1Gi        RWX            config3        34s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
$  ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep pvc-b7355ed0-45a7-48bd-896f-c06c2cf7f7c7"
192.168.0.132:/cfg3_pvc_b7355ed0_45a7_48bd_896f_c06c2cf7f7c7 on /var/lib/kubelet/pods/3a1f7ddb-70ef-4a84-935f-6a535f68c0c0/volumes/kubernetes.io~csi/pvc-b7355ed0-45a7-48bd-896f-c06c2cf7f7c7/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.132,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.132)
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
$ kubectl create -f config.yaml
namespace/config4 created
persistentvolumeclaim/pvc4 created
pod/pod4 created

$ kubectl get -n config4 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod4   1/1     Running   0          29s   192.168.24.63   rhel1   <none>           <none>

$ kubectl get -n config4 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc4   Bound    pvc-c92c72a1-a515-4885-a68a-8aefb3ce1ccb   1Gi        RWX            config4        33s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
$ ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep pvc-c92c72a1-a515-4885-a68a-8aefb3ce1ccb"
192.168.0.132:/cfg4_pvc_c92c72a1_a515_4885_a68a_8aefb3ce1ccb on /var/lib/kubelet/pods/b35507b0-2c2f-4cb4-9ce6-9abd84f34614/volumes/kubernetes.io~csi/pvc-c92c72a1-a515-4885-a68a-8aefb3ce1ccb/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.132,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.132)
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
cluster1::> nfs modify -vserver nfs_svm -v3-hide-snapshot enabled
```

The _config3_ backend contains the parameter _snapshotDir: 'true'_, which gives access to the .snapshot directory.  

The _sc13-config5.yaml_ file will create a PVC (using the backend _config3_) & a POD in a new namespace called _config5_:
```bash
$ kubectl create -f config5.yaml
namespace/config5 created
persistentvolumeclaim/pvc5 created
pod/pod5 created

$ kubectl get -n config5 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod5   1/1     Running   0          14s   192.168.24.21   rhel1   <none>           <none>

$ kubectl get -n config5 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc5   Bound    pvc-5e164299-61c2-40c2-be31-d8a2189198ad   1Gi        RWX            config3        17s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep pvc-5e164299-61c2-40c2-be31-d8a2189198ad"
192.168.0.132:/cfg3_pvc_5e164299_61c2_40c2_be31_d8a2189198ad on /var/lib/kubelet/pods/6f0a853d-90ab-46e8-b607-ebd5161d9f52/volumes/kubernetes.io~csi/pvc-5e164299-61c2-40c2-be31-d8a2189198ad/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.132,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.132)
```
As expected, we are using NFSv3.  
Let's create a snapshot (using the _sc13-config5-snapshot-create.sh_ script) & verify if we can see it and access it:
```bash
$ sh sc13-config5-snapshot-create.sh

k exec -n config5 pod5 -- ls -la /data
total 4
drwxrwxrwx    2 root     root          4096 Aug 27 19:58 .
drwxr-xr-x    1 root     root            29 Aug 27 19:58 ..

k exec -n config5 pod5 -- ls -la /data/.snapshot
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
$ kubectl create -f config6.sh
namespace/config6 created
persistentvolumeclaim/pvc6 created
pod/pod5 created

$ kubectl get -n config6 pod -o wide
NAME   READY   STATUS    RESTARTS   AGE     IP              NODE    NOMINATED NODE   READINESS GATES
pod6   1/1     Running   0          2m24s   192.168.24.19   rhel1   <none>           <none>

$ kubectl get -n config6 pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc6   Bound    pvc-dcd6bda1-bc65-4745-973f-f3848c085c0c   1Gi        RWX            config4        2m28s
```
As the pod runs on the node RHEL1, let's see what version of NFS is used to mount the volume:
```bash
ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep pvc-dcd6bda1-bc65-4745-973f-f3848c085c0c"
192.168.0.132:/cfg4_pvc_dcd6bda1_bc65_4745_973f_f3848c085c0c on /var/lib/kubelet/pods/1733cdde-65fd-4429-8314-2b542d5cc47f/volumes/kubernetes.io~csi/pvc-dcd6bda1-bc65-4745-973f-f3848c085c0c/mount type nfs (rw,relatime,vers=3,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.0.132,mountvers=3,mountport=635,mountproto=udp,local_lock=none,addr=192.168.0.132)
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

Unless you want to run some extra tests, you can delete all 6 namespaces used here:
```bash
$ kubectl get ns -o name | grep config[1-6] | xargs kubectl delete
namespace "config1" deleted
namespace "config2" deleted
namespace "config3" deleted
namespace "config4" deleted
namespace "config5" deleted
namespace "config6" deleted
```
You can also modify the SVM in order to bring it back to its previous configuration with regards to the v3-hide-snapshot parameter:
```bash
cluster1::> nfs modify -vserver nfs_svm -v3-hide-snapshot disabled
```
