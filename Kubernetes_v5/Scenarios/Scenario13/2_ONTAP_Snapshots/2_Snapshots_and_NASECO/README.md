#########################################################################################
# SCENARIO 13: ONTAP Snapshots & ONTAP-NAS-ECONOMY
#########################################################################################  

Snapshots are objects that are tightly linked to FlexVol (ONTAP Volumes), while Qtrees are some kind of subdirectories within a FlexVol.  
The ONTAP-NAS-ECONOMY Trident driver allows you to create Qtrees upon PVC request.  
Up to 300 PVC/Qtrees can be configured per FlexVol in this context (minimum 50 / default 200).  

As Snapshots & Qtrees are not on the same layer, CSI Snapshots are not supported with the ONTAP-NAS-ECONOMY.  
However, scheduled ONTAP snapshots are available!  
Let's see this in action.  

We will use 3 POD/PVC, each in their own namespace.  
Note that the _nas-eco-default_ backend configured in the [Scenario02](../../../Scenario02) contains the parameter _snapshotDir:true_.  

```bash
$ kubectl create -f sc13_qtrees_setup.yaml
namespace/bbox1 created
persistentvolumeclaim/pvc1 created
pod/pod1 created
namespace/bbox2 created
persistentvolumeclaim/pvc2 created
pod/pod2 created
namespace/bbox3 created
persistentvolumeclaim/pvc3 created
pod/pod3 created
```

In order to confirm that all 3 PVC/Qtrees are under one single FlexVol, you can run the _qtree-list.sh_ script which will give you via REST API all the Qtrees that are in the same FlexVol used by PVC1:
```bash
$ sh qtree_list.sh
FLEXVOL NAME:
trident_qtree_pool_nas2_GAFIKTPKRB
QTREES:
nas2_pvc_7c949cd3_c737_4f64_a37a_2f9a3cfe0dcc
nas2_pvc_da8e0e3b_69af_4beb_880f_fd24c48e2cb6
nas2_pvc_0cbad48c_dc48_4145_b894_cd0ec73cda49
```

Let's create some simple content (one file) in each pod:
```bash
kubectl exec pod1 -n bbox1 -- sh -c 'echo POD1 > /data/pod1.txt'
kubectl exec pod2 -n bbox2 -- sh -c 'echo POD2 > /data/pod2.txt'
kubectl exec pod3 -n bbox3 -- sh -c 'echo POD3 > /data/pod3.txt'
```

Time to create a snapshot & witness what happens !  
The script _snapshot-create.sh_ will create a snapshot called _scenario13_ in the FlexVol that owns all 3 qtrees:
```bash
sh snapshot-create.sh
```

Let's modify or erase some information, to put you in the context of a restore operation:
```bash
$ kubectl exec pod1 -n bbox1 -- rm -f /data/pod1.txt
$ kubectl exec pod1 -n bbox1 -- ls /data/

$ kubectl exec pod2 -n bbox2 -- sh -c 'echo "NOT THE DATA I WANT" > /data/pod2.txt'
$ kubectl exec pod2 -n bbox2 -- more /data/pod2.txt
NOT THE DATA I WANT
```

Let's check if we can see it in each pod:
```bash
$ kubectl exec pod1 -n bbox1 -- ls -la /data/
total 4
drwxrwxrwx    2 99       99            4096 Aug 27 17:59 .
drwxr-xr-x    1 root     root            29 Aug 27 17:54 ..

$ kubectl exec pod1 -n bbox1 -- ls  /data/.snapshot/
scenario13
$ kubectl exec pod1 -n bbox1 -- ls  /data/.snapshot/scenario13
pod1.txt

$ kubectl exec pod2 -n bbox2 -- ls  /data/.snapshot/
scenario13
$ kubectl exec pod2 -n bbox2 -- ls  /data/.snapshot/scenario13
pod2.txt
$ kubectl exec pod2 -n bbox2 -- more  /data/.snapshot/scenario13/pod2.txt
POD2

$ kubectl exec pod3 -n bbox3 -- ls  /data/.snapshot/
scenario13
$ kubectl exec pod3 -n bbox3 -- ls  /data/.snapshot/scenario13
pod3.txt
```

From there you could just copy & paste the files you need to restore, in order to come back to the initial state:
```bash
$ kubectl exec pod1 -n bbox1 -- cp /data/.snapshot/scenario13/pod1.txt /data/
$ kubectl exec pod1 -n bbox1 -- ls /data/
pod1.txt

$ kubectl exec pod2 -n bbox2 -- cp /data/.snapshot/scenario13/pod2.txt /data/
$ kubectl exec pod2 -n bbox2 -- more /data/pod2.txt
POD2
```

Notice that even though the snapshot contains all the data of the FlexVol (hence all 3 qtrees), each POD only sees its own data!  

Also, by default on this lab, mounts use NFv4.1, which explains why the _.snapshot_ folder is hidden.  
Let's verify that on the first PVC mounted on the host _rhel1_.  
```bash
$ kubectl get pod -n bbox1 -o wide
NAME   READY   STATUS    RESTARTS       AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod1   1/1     Running   25 (31m ago)   25h   192.168.24.62   rhel1   <none>           <none>

$ kubectl get pvc -n bbox1
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                AGE
pvc1   Bound    pvc-7c949cd3-c737-4f64-a37a-2f9a3cfe0dcc   1Gi        RWX            storage-class-nas-economy   25h

$ ssh -o "StrictHostKeyChecking no" root@rhel1 -t "mount | grep nas2_pvc_7c949cd3_c737_4f64_a37a_2f9a3cfe0dcc"
192.168.0.132:/trident_qtree_pool_nas2_GAFIKTPKRB/nas2_pvc_7c949cd3_c737_4f64_a37a_2f9a3cfe0dcc on /var/lib/kubelet/pods/ffba9872-c5c1-45e3-a8ba-6662cd781424/volumes/kubernetes.io~csi/pvc-7c949cd3-c737-4f64-a37a-2f9a3cfe0dcc/mount type nfs4 (rw,relatime,vers=4.1,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,clientaddr=192.168.0.61,local_lock=none,addr=192.168.0.132)
```

Also, keep in mind that the _snapshot reserve_ is also set at the FlexVol level.  
The parameter default to 5% of the FlexVol size.  

Time for some clean up:
```bash
$ kubectl get ns -o name | grep bbox | xargs kubectl delete
namespace "bbox1" deleted
namespace "bbox2" deleted
namespace "bbox3" deleted
```