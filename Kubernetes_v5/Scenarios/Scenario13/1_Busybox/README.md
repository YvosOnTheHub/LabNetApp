#########################################################################################
# SCENARIO 13: CSI Snapshots with Busybox
#########################################################################################

This chapter will lead you in the management of snapshots with a simple lightweight container BusyBox.

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario13_busybox_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 **optional** parameters, your Docker Hub login & password:

```bash
sh scenario13_busybox_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create an app in its own namespace (also very useful to clean up everything).  
For this scenario, we will use a specific backend, as well as a storage class, in order to see how snapshot space usage is calculated.  
I specifically chose a high snapshot reserve value of 40%, so that we can really see the impact.  

```bash
$ kubectl create -n trident -f backend_nas-snap_reserve.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-snap-reserve created
$ kubectl create -f sc-csi-ontap-nas_snap-reserve.yaml
storageclass.storage.k8s.io/storage-class-nas-snap-reserve created

$ kubectl create namespace busybox
namespace/busybox created

$ kubectl create -n busybox -f busybox.yaml
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n busybox all,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-784bb778fb-ppktt   1/1     Running   0          58s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/busybox   1/1     1            1           58s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/busybox-784bb778fb   1         1         1       58s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                     AGE
persistentvolumeclaim/mydata   Bound    pvc-24592dc4-1955-4e9e-82eb-843acbf3c69b   10Gi       RWX            storage-class-nas-snap-reserve   58s
```

## B. Create a snapshot

Before doing so, let's create a file in our PVC, that will be deleted once the snapshot is created.  
That way, there is a difference between the current filesystem & the snapshot content.  

```bash
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
192.168.0.132:/sr_pvc_24592dc4_1955_4e9e_82eb_843acbf3c69b
                         10.0G    256.0K     10.0G   0% /data

$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- touch /data/test.txt
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/test.txt
-rw-r--r--    1 99       99               0 Jun 16 13:19 /data/test.txt
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- sh -c 'echo "Trident is great!" > /data/test.txt'
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- more /data/test.txt
Trident is great!
```

The PVC has been requested for 10GB, which is also what you can see in the POD.  
However, let's take a look at the ONTAP level.  

```bash
$ export VOLUME=$(kubectl get pv $( kubectl get pvc mydata -n busybox -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}')
$ echo $VOLUME
sr_pvc_24592dc4_1955_4e9e_82eb_843acbf3c69b

$ ssh -l vsadmin 192.168.0.135 vol show -volume $VOLUME -fields size,available,percent-snapshot-space
vserver volume                                      size    available percent-snapshot-space
------- ------------------------------------------- ------- --------- --------------------------
nfs_svm sr_pvc_24592dc4_1955_4e9e_82eb_843acbf3c69b 16.67GB 10.00GB   40%
```

We have set a 40% snapshot reserve in the backend file, space that is not taken from the PVC size.  
The overall size of the volume in ONTAP will be calculated as follows: PVC_Size / ((100 - Snap_Reserve)/100), hence the 16GB you can see here.  

Now, we can proceed with the snapshot creation

```bash
$ kubectl create -n busybox -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n busybox
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              268Ki         csi-snap-class   ssnapcontent-2512951e-f7ba-4be5-b508-494dc1fb0bdb   5s             5s

$ tridentctl -n trident get volume
+------------------------------------------+--------+--------------------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE  |         STORAGE CLASS          | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+--------+--------------------------------+----------+--------------------------------------+--------+---------+
| pvc-24592dc4-1955-4e9e-82eb-843acbf3c69b | 10 GiB | storage-class-nas-snap-reserve | file     | cefe7d92-5de1-41ee-bb40-253caa970277 | online | true    |
+------------------------------------------+--------+--------------------------------+----------+--------------------------------------+--------+---------+

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+
|                     NAME                      |                  VOLUME                  |
+-----------------------------------------------+------------------------------------------+
| snapshot-2512951e-f7ba-4be5-b508-494dc1fb0bdb | pvc-24592dc4-1955-4e9e-82eb-843acbf3c69b |
+-----------------------------------------------+------------------------------------------+
```

Your snapshot has been created !  
But what does it translate to at the storage level?  
With ONTAP, you will end up with a *ONTAP Snapshot*, a _ReadOnly_ object, which is instantaneous & space efficient!  
You can see it by browsing through System Manager, by connecting with Putty to the _cluster1_ profile (admin/Netapp1!) or using the following SSH command:

```bash
$ ssh -l vsadmin 192.168.0.135 vol snaps show -volume $VOLUME
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
nfs_svm  sr_pvc_24592dc4_1955_4e9e_82eb_843acbf3c69b
                  snapshot-2512951e-f7ba-4be5-b508-494dc1fb0bdb 160KB 0%  56%
                  hourly.2022-07-05_0705                   196KB     0%   37%
                  hourly.2022-07-05_0805                   216KB     0%   39%
```

Notice, that you may also see ONTAP scheduled snapshots.
About those, you can easily access them from within the container, but only if you set the parameter _snapshotDir: 'true'_ in the Trident Backend configuration.

```bash
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/.snapshot/
total 12
drwxrwxrwx    2 99       99            4096 Jul  5 08:18 hourly.2022-07-05_0705
drwxrwxrwx    2 99       99            4096 Jul  5 08:18 hourly.2022-07-05_0805
drwxrwxrwx    2 99       99            4096 Jul  5 08:18 snapshot-2512951e-f7ba-4be5-b508-494dc1fb0bdb

$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/.snapshot/snapshot-2512951e-f7ba-4be5-b508-494dc1fb0bdb
total 0
-rw-r--r--    1 99       99              18 Jul  5 07:19 test.txt
```

Finally, let's delete the file we created earlier.

```bash
kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- rm -f /data/test.txt
```

## C. Create a clone (ie a _PVC from Snapshot_)

Having a snapshot can be useful to create a new PVC.  
If you take a look a the PVC manifest (_pvc_from_snap.yaml_), you can notice the reference to the snapshot:

```bash
  dataSource:
    name: mydata-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

Let's see how that turns out:

```bash
$ kubectl create -n busybox -f pvc_from_snap.yaml
persistentvolumeclaim/mydata-from-snap created

$ kubectl get pvc,pv -n busybox
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                     AGE
persistentvolumeclaim/mydata             Bound    pvc-24592dc4-1955-4e9e-82eb-843acbf3c69b   10Gi       RWX            storage-class-nas-snap-reserve   15m
persistentvolumeclaim/mydata-from-snap   Bound    pvc-c506b7f4-40b2-4bc8-a5c4-48c41006e5bf   10Gi       RWX            storage-class-nas-snap-reserve   2m7s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                      STORAGECLASS                     REASON   AGE
persistentvolume/pvc-24592dc4-1955-4e9e-82eb-843acbf3c69b   10Gi       RWX            Delete           Bound    busybox/mydata             storage-class-nas-snap-reserve            15m
persistentvolume/pvc-c506b7f4-40b2-4bc8-a5c4-48c41006e5bf   10Gi       RWX            Delete           Bound    busybox/mydata-from-snap   storage-class-nas-snap-reserve            2m6s
```

Your clone has been created, but what does it translate to at the storage level?  
With ONTAP, you will end up with a *FlexClone*, which is instantaneous & space efficient!  
Said differently,  you can imagine it as a _ReadWrite_ snapshot...  
You can see this object by browsing through System Manager, by connecting with Putty to the _cluster1_ profile (admin/Netapp1!) or other means:

```bash
$ curl -X GET -ku vsadmin:Netapp1!  "https://192.168.0.135/api/storage/volumes?clone.is_flexclone=true&fields=clone.parent_volume.name,clone.parent_snapshot.name" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "481a1715-fc34-11ec-8bed-005056b0bfd4",
      "name": "sr_pvc_c506b7f4_40b2_4bc8_a5c4_48c41006e5bf",
      "clone": {
        "is_flexclone": true,
        "parent_snapshot": {
          "name": "snapshot-2512951e-f7ba-4be5-b508-494dc1fb0bdb"
        },
        "parent_volume": {
          "name": "sr_pvc_24592dc4_1955_4e9e_82eb_843acbf3c69b"
        }
      }
    }
  ],
  "num_records": 1
}
```

## D. Recover the data of your application

When it comes to data recovery, there are many ways to do so. If you want to recover only one file, you could browser through the .snapshot folders & copy/paste what you need. However, if you want to recover everything, you could very well update your application manifest to point to the clone, which is what we are going to see:

```bash
$ kubectl patch -n busybox deploy busybox -p '{"spec":{"template":{"spec":{"volumes":[{"name":"volume","persistentVolumeClaim":{"claimName":"mydata-from-snap"}}]}}}}'
deployment.apps/busybox patched
```

That will trigger a new POD creation with the updated configuration:

```bash
$ kubectl get -n busybox pod
NAME                       READY   STATUS        RESTARTS   AGE
busybox-784bb778fb-ppktt   1/1     Terminating   0          20m
busybox-7c8856686-s4zpc    1/1     Running       0          11s
```

Now, if you look at the files this POD has access to (the PVC), you will see that the *lost data* (file: test.txt) is back!

```bash
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/
total 0
-rw-r--r--    1 99       99              18 Jul  5 07:19 test.txt
```

Tadaaa, you have restored your data!  
Keep in mind that some applications may need some extra care once the data is restored (databases for instance).  
& that is why NetApp Astra is taking care of !

## Optional Cleanup

```bash
$ kubectl delete ns busybox
namespace "busybox" deleted
```

## What's next

You can now move on to:

- [Apps & CSI Snapshots](../2_Ghost): Use snapshots with Ghost  
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)