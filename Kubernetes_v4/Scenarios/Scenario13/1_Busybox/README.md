#########################################################################################
# SCENARIO 13: CSI Snapshots with Busybox
#########################################################################################

This chapter will lead you in the management of snapshots with a simple lightweight container BusyBox.

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario13_busybox_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario13_busybox_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create an app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-NAS backend & storage class have already been created. (cf [Scenario02](../../Scenario02)).  

```bash
$ kubectl create namespace busybox
namespace/busybox created

$ kubectl create -n busybox -f busybox.yaml
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get all -n busybox
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-767768d776-dh929   1/1     Running   0          5m1s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/busybox   1/1     1            1           5m1s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/busybox-767768d776   1         1         1       5m1s

$ kubectl get pvc,pv -n busybox
NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata   Bound    pvc-e6a0aad2-d135-408f-aae4-5477238cabcc   1Gi        RWX            storage-class-nas   7m28s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM            STORAGECLASS        REASON   AGE
persistentvolume/pvc-e6a0aad2-d135-408f-aae4-5477238cabcc   1Gi        RWX            Delete           Bound    busybox/mydata   storage-class-nas            7m26s
```

## B. Create a snapshot

Before doing so, let's create a file in our PVC, that will be deleted once the snapshot is created.  
That way, there is a difference between the current filesystem & the snapshot content.  

```bash
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- df /data
Filesystem           1K-blocks      Used Available Use% Mounted on
192.168.0.135:/nas1_pvc_e6a0aad2_d135_408f_aae4_5477238cabcc
                        996160       256    995904   0% /data

$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- touch /data/test.txt
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/test.txt
-rw-r--r--    1 99       99               0 Jun 16 13:19 /data/test.txt
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- sh -c 'echo "Trident is great!" > /data/test.txt'
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- more /data/test.txt
Trident is great!
```

Now, we can proceed with the snapshot creation

```bash
$ kubectl create -n busybox -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n busybox
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              1Gi           csi-snap-class   snapcontent-6376456d-b4f6-4def-b572-0a0b295295ae   5s             5s

$ tridentctl -n trident get volume
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-e6a0aad2-d135-408f-aae4-5477238cabcc | 1.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+
|                     NAME                      |                  VOLUME                  |
+-----------------------------------------------+------------------------------------------+
| snapshot-6376456d-b4f6-4def-b572-0a0b295295ae | pvc-e6a0aad2-d135-408f-aae4-5477238cabcc |
+-----------------------------------------------+------------------------------------------+
```

Your snapshot has been created !  
But what does it translate to at the storage level?  
With ONTAP, you will end up with a *ONTAP Snapshot*, a _ReadOnly_ object, which is instantaneous & space efficient!  
You can see it by browsing through System Manager, by connecting with Putty to the _cluster1_ profile (admin/Netapp1!) or using the following SSH command:

```bash
$ kubectl get pv $( kubectl get pvc mydata -n busybox -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
nas1_pvc_e6a0aad2_d135_408f_aae4_5477238cabcc

$ ssh -l vsadmin 192.168.0.135 vol snaps show -volume nas1_pvc_e6a0aad2_d135_408f_aae4_5477238cabcc
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
nfs_svm  nas1_pvc_e6a0aad2_d135_408f_aae4_5477238cabcc
                  snapshot-6376456d-b4f6-4def-b572-0a0b295295ae 208KB 0%  32%
                  daily.2021-06-17_0010                    256KB     0%   36%
                  hourly.2021-06-17_0205                   272KB     0%   38%
```

Notice, that you may also see ONTAP scheduled snapshots.
About those, you can easily access them from within the container, but only if you set the parameter _snapshotDir: 'true'_ in the Trident Backend configuration.

```bash
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/.snapshot/
total 32
drwxrwxrwx    2 99       99            4096 Jun 16 13:19 daily.2021-06-17_0010
drwxrwxrwx    2 99       99            4096 Jun 16 13:19 hourly.2021-06-17_0205
drwxrwxrwx    2 99       99            4096 Jun 16 13:19 snapshot-6376456d-b4f6-4def-b572-0a0b295295ae

$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls -l /data/.snapshot/snapshot-6376456d-b4f6-4def-b572-0a0b295295ae
total 0
-rw-r--r--    1 99       99               6 Jun 16 13:22 test.txt
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
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata             Bound    pvc-e6a0aad2-d135-408f-aae4-5477238cabcc   1Gi        RWX            storage-class-nas   19h
persistentvolumeclaim/mydata-from-snap   Bound    pvc-8cc7c1f7-399c-4a85-9b0d-d8fbd05e6c1f   1Gi        RWX            storage-class-nas   11s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                      STORAGECLASS        REASON   AGE
persistentvolume/pvc-8cc7c1f7-399c-4a85-9b0d-d8fbd05e6c1f   1Gi        RWX            Delete           Bound    busybox/mydata-from-snap   storage-class-nas            9s
persistentvolume/pvc-e6a0aad2-d135-408f-aae4-5477238cabcc   1Gi        RWX            Delete           Bound    busybox/mydata             storage-class-nas            19h
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
      "uuid": "f434ba34-cf43-11eb-83c4-005056b03185",
      "name": "nas1_pvc_8cc7c1f7_399c_4a85_9b0d_d8fbd05e6c1f",
      "clone": {
        "is_flexclone": true,
        "parent_snapshot": {
          "name": "snapshot-6376456d-b4f6-4def-b572-0a0b295295ae"
        },
        "parent_volume": {
          "name": "nas1_pvc_e6a0aad2_d135_408f_aae4_5477238cabcc"
        }
      }
    }
  ],
  "num_records": 1
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
busybox-69f765569b-rh2fs   1/1     Running       0          5s
busybox-767768d776-dh929   1/1     Terminating   19         19h
```

Now, if you look at the files this POD has access to (the PVC), you will see that the *lost data* (file: test.txt) is back!

```bash
$ kubectl exec -n busybox $(kubectl get pod -n busybox -o name) -- ls /data/
total 0
-rw-r--r--    1 99       99              18 Jun 17 12:51 test.txt
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