#########################################################################################
# SCENARIO 13: In-place snapshot restore
#########################################################################################

Trident 24.06.1 introduced the possibility to perform an in-place CSI Snapshot restore.  

This chapter will lead you in the management of snapshots with a simple lightweight container BusyBox.

**In-place snapshot restore can only be achieved by following these requirements**:
- the PVC must be disconnected to its POD for the restore to succeed  
- only the newest CSI snapshot can be restored  
- this feature is not supported with the ONTAP-NAS-ECONOMY driver

You can find a shell script in this directory _scenario13_busybox_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 **optional** parameters, your Docker Hub login & password:  
```bash
sh scenario13_busybox_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create an app in its own namespace _sc03busybox_ (also very useful to clean up everything).   
The storage class & backend for NFS should already be configured [cf Scenario02](../../../Scenario02/1_Local_User/).  
```bash
$ kubectl create -f busybox.yaml
namespace/sc13busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc13busybox pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-8589754dc6-8q95c   1/1     Running   0          34s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-80fb0a5c-d98e-40bb-a762-2e5d14b19e41   1Gi        RWX            storage-class-nfs   <unset>                 35s
```

## B. Create a CSI snapshot

Before doing so, let's create a file in our PVC, that will be deleted once the snapshot is created.  
That way, there is a difference between the current filesystem & the snapshot content.  

```bash
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
192.168.0.131:/trident_pvc_80fb0a5c_d98e_40bb_a762_2e5d14b19e41
                          1.0G    256.0K   1023.8M   0% /data

$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- touch /data/test.txt
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- ls -l /data/test.txt
-rw-r--r--    1 root     root             0 Jul 30 12:46 /data/test.txt
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- sh -c 'echo "Check out Trident !" > /data/test.txt'
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- more /data/test.txt
Check out Trident!
```
Now, we can proceed with the snapshot creation
```bash
$ kubectl create -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n sc13busybox
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              276Ki         csi-snap-class   snapcontent-13b3c2cf-f469-4f81-ad08-2256d80dc56b   14s            15s
```
Your snapshot has been created !  

Let's delete the file we created earlier, before restoring the snapshot.  
```bash
kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- rm -f /data/test.txt
```

What do we have on the storage layer?  
```bash
$ export VOLUME=$(kubectl get pv $( kubectl get pvc mydata -n sc13busybox -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}')
$ echo $VOLUME
trident_pvc_02726290_d6bc_4035_8dc0_6365ded090ed

$ ssh -l vsadmin 192.168.0.133 vol snaps show -volume $VOLUME
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
nassvm   trident_pvc_02726290_d6bc_4035_8dc0_6365ded090ed
                  snapshot-13b3c2cf-f469-4f81-ad08-2256d80dc56b 184KB 0%  39%
```


## C. Perform an in-place restore of the data.

When it comes to data recovery, there are many ways to do so. If you want to recover only one file, you could browser through the .snapshot folder (if accessible) & copy/paste what you need. However, for a large dataset, copying everything will take a long time.  
In-place restore will benefit from the ONTAP Snapshot Restore feature, which takes only a couple of seconds whatever size the volume is!  

In order to use this feature, the volume needs to be detached from its pods.  
Since we are using a deployment object, we can just scale it down to 0:  
```bash
$ kubectl scale -n sc13busybox deploy busybox --replicas=0
deployment.apps/busybox scaled
$ kubectl get -n sc13busybox pod
No resources found in sc13busybox namespace.
```

In-place restore will be performed by created a TASR objet ("TridentActionSnapshotRestore"):  
```bash
$ kubectl create -f snapshot-restore.yaml
tridentactionsnapshotrestore.trident.netapp.io/mydatarestore created
$ kubectl get -n sc13busybox tasr -o=jsonpath='{.items[0].status.state}'; echo
Succeeded
```

We can now restart the pod, and browse through the PVC content.  
If you look at the files this POD has access to (the PVC), you will see that the *lost data* (file: test.txt) is back!
```bash
$ kubectl scale -n sc13busybox deploy busybox --replicas=1
deployment.apps/busybox scaled

$ kubectl get -n sc13busybox pod
NAME                       READY   STATUS    RESTARTS   AGE
busybox-77797b84d8-6jt5r   1/1     Running   0          10s

$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- ls -l /data/
total 0
-rw-r--r--    1 root     root            20 Jul 30 12:47 test.txt
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- more /data/test.txt
Check out Trident!
```
Tadaaa, you have restored the whole snapshot in one shot!  

## D. Error use cases: multiple CSI Snapshots

Let's take the same application and add 2 new volume snapshots:
```bash
$ kubectl create -f pvc-2snapshots.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot1 created
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot2 created

$ kubectl get -n sc13busybox vs
NAME               READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot    true         mydata                              276Ki         csi-snap-class   snapcontent-6e9bd26b-4d67-4687-85dc-db52eb4b1bd9   10m            10m
mydata-snapshot1   true         mydata                              508Ki         csi-snap-class   snapcontent-12b3794f-d270-4b03-91ac-107e84b78215   64s            65s
mydata-snapshot2   true         mydata                              684Ki         csi-snap-class   snapcontent-2b8e1a4c-c507-47e7-86ca-39264e78f040   64s            65s

$ ssh -l vsadmin 192.168.0.133 vol snaps show -volume $VOLUME
                                                                ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
nassvm   trident_pvc_02726290_d6bc_4035_8dc0_6365ded090ed
                  snapshot-13b3c2cf-f469-4f81-ad08-2256d80dc56b 164KB 0%  35%
                  snapshot-01a5bcc5-17e9-4851-a598-792e35aeb554 176KB 0%  36%
                  snapshot-3b7738ae-d7c9-4cfb-a065-74b56a285855 156KB 0%  34%
3 entries were displayed.
```

_mydata-snapshot2_ being the newest one, what happens if you try to restore again the first one (_mydata-snapshot_).  
It will fail with an explicit message in the logs or in the description of the TASR object:  
```bash
$ kubectl scale -n sc13busybox deploy busybox --replicas=0
deployment.apps/busybox scaled

$ kubectl create -f snapshot-restore1.yaml
tridentactionsnapshotrestore.trident.netapp.io/mydatarestore1 created

$ kubectl get -n sc13busybox tasr -o=jsonpath='{.items[1].status}' | jq
{
  "completionTime": "2024-07-30T13:21:54Z",
  "message": "volume snapshot mydata-snapshot is not the newest snapshot of PVC sc13busybox/mydata",
  "state": "Failed"
}

$ kubectl delete -f snapshot-restore.yaml 
tridentactionsnapshotrestore.trident.netapp.io "mydatarestore1" deleted
$ kubectl delete -f pvc-2snapshots.yaml 
volumesnapshot.snapshot.storage.k8s.io "mydata-snapshot1" deleted
volumesnapshot.snapshot.storage.k8s.io "mydata-snapshot2" deleted
```

## E. Error use cases: PVC attached to a POD

If you try to restore a CSI snapshot that is attached to a POD, it will also fail with an explicit message in the logs.  
You indeed first need to scale down the POD that attaches the PVC for the restore operation to succeed.  
```bash
$ kubectl scale -n sc13busybox deploy busybox --replicas=1
deployment.apps/busybox scaled

$ kubect get -n sc13busybox pod
NAME                       READY   STATUS    RESTARTS   AGE
busybox-8589754dc6-hsmnb   1/1     Running   0          40s

$ kubectl create -f snapshot-restore2.yaml
tridentactionsnapshotrestore.trident.netapp.io/mydatarestore2 created

$ kubectl get -n sc13busybox tasr -o=jsonpath='{.items[0].status}' | jq
{
  "completionTime": "2024-07-30T13:27:27Z",
  "message": "cannot restore attached volume to snapshot",
  "startTime": "2024-07-30T13:27:27Z",
  "state": "Failed"
}

$ kubectl delete -f snapshot-restore2.yaml 
tridentactionsnapshotrestore.trident.netapp.io "mydatarestore2" deleted
```

## Optional Cleanup

```bash
$ kubectl delete ns sc13busybox
namespace "sc01busybox" deleted
```