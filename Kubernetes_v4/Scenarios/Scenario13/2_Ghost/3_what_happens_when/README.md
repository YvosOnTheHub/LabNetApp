#########################################################################################
# SCENARIO 13.3: What happens when ...
#########################################################################################

PVC, Snapshots & Clones (ie PVC-from-snapshot) are 3 related, but independent, Kubernetes objects.  
However, at the infrastructure level, within ONTAP, these objects have a tight relationship.  

So, what happens if you delete a PVC or a snapshot, how does it affect other objects?  
Well, the good news is that there is no impact...  

## A. Prepare the environment

At this point, you should have:

- a PVC (*mydata*)
- a Snapshot (*mydata-snapshot*)
- a Clone (*mydata-from-snap*)

Also, if you went through the parts 1 & 2 of this scenario, you may still have PODs & Services configured.  
Let's start by cleaning this up (remove the Deployment & the services, so that we can work on PVCs).  
Depending on which part of this scenario you have done, you can use one or both of the following blocks:

```bash
$ kubectl delete -n ghost all -l app=blog
pod "blog-6cbd945df-p8r8t" deleted
service "blog" deleted
deployment.apps "blog" deleted
replicaset.apps "blog-6d864d5bb" deleted


$ kubectl delete -n ghost all -l app=blogclone
pod "blogclone-6d864d5bb-kbbdr" deleted
service "blogclone" deleted
deployment.apps "blogclone" deleted
replicaset.apps "blogclone-6d864d5bc" deleted
```

Once the cleanup is done, you will only have the following left:

```bash
$ kubectl get -n ghost pvc,volumesnapshot
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata             Bound    pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3   5Gi        RWX            storage-class-nas   104m
persistentvolumeclaim/mydata-from-snap   Bound    pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            storage-class-nas   20m

NAME                                                     READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot   true         mydata                              5Gi           csi-snap-class   snapcontent-3a286486-7a69-499d-b9d7-163e3f62892c   31m            31m

$ tridentctl -n trident get volume
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc | 5.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | online | true    |
| pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3 | 5.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+
|                     NAME                      |                  VOLUME                  |
+-----------------------------------------------+------------------------------------------+
| snapshot-3a286486-7a69-499d-b9d7-163e3f62892c | pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3 |
+-----------------------------------------------+------------------------------------------+
```

## B. Seek & destroy : PVC

Let's start by deleting the parent PVC.  

```bash
$ kubectl delete -n ghost pvc mydata
persistentvolumeclaim "mydata" deleted
```

This operation took no time, & here is what we have left within our namespace in Kubernetes:

```bash
$ kubectl get -n ghost pvc,pv
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata-from-snap   Bound    pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            storage-class-nas   21m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS        REASON   AGE
persistentvolume/pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            Delete           Bound    ghost/mydata-from-snap   storage-class-nas            21m

$ kubectl get -n ghost volumesnapshot
mydata-snapshot   true         mydata                              5Gi           csi-snap-class   snapcontent-3a286486-7a69-499d-b9d7-163e3f62892c   34m            34m
```

As expected, the *mydata* PVC & its PV are gone from the configuration.  
However, what do we see from a Trident point of view:

```bash
$ tridentctl -n trident get volumes
+------------------------------------------+---------+-------------------+----------+--------------------------------------+----------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             |  STATE   | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+----------+---------+
| pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc | 5.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | online   | true    |
| pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3 | 5.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | deleting | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+----------+---------+

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+
|                     NAME                      |                  VOLUME                  |
+-----------------------------------------------+------------------------------------------+
| snapshot-3a286486-7a69-499d-b9d7-163e3f62892c | pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3 |
+-----------------------------------------------+------------------------------------------+
```

We still have 2 volumes configured!  
Notice that the volume we just removed is in a *deleting* state.  
Trident is actually going to physically remove the volume only once every CSI Snapshots are deleted!

## C. Seek & destroy : Snapshot

Let's delete the CSI Snapshot we created earlier.

```bash
$ kubectl get -n ghost volumesnapshot
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              5Gi           csi-snap-class   snapcontent-3a286486-7a69-499d-b9d7-163e3f62892c   35m            35m

$ kubectl delete -n ghost volumesnapshot mydata-snapshot
volumesnapshot.snapshot.storage.k8s.io "mydata-snapshot" deleted
```

This operation takes a little bit more time than the PVC deletion.  
Let's look at what we have left:

```bash
$ kubectl get -n ghost pvc,pv
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata-from-snap   Bound    pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            storage-class-nas   25m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS        REASON   AGE
persistentvolume/pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            Delete           Bound    ghost/mydata-from-snap   storage-class-nas            25m

$ tridentctl -n trident get snapshot
+------+--------+
| NAME | VOLUME |
+------+--------+
+------+--------+
$ tridentctl -n trident get volume
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc | 5.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
```

The snapshot & the first volume are now gone from both Kubernetes & Trident.  
We are left with the PVC we created from the snapshot.  

In this configuration, deleting the snapshot & the parent PVC triggered 2 operations:

- as the volume had no CSI Snapshot left, Trident launched the deletion of this volume
- within ONTAP, a clone is also linked to its parent volume. Deleting the volume also meant performing a "split clone" operation on the second volume, which means transform a clone into a volume of its own. This operation happens on the background, with no impact.  

Bottom line, deleting a PVC or a snapshot will no have any impact on the infrastructure!

## D. Optional Cleanup (only if you are done playing with the scenario14)

```bash
$ kubectl delete ns ghost
namespace "ghost" deleted
```

## What's next

You can fo back to the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
