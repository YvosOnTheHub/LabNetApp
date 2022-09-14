#########################################################################################
# SCENARIO 8: Consumption control: what about CSI snapshots
#########################################################################################

You have seen in the Scenario8 various ways to control Persistent Volumes, in terms of numbers & capacity.  
There is also a way to control the number of CSI snapshots that can be created in Kubernetes.  

The method does not use a pre-built quota, however Kubernetes allows you to create quotas on different other resources.  

More information on this topic can be found on those links:

- https://kubernetes.io/docs/concepts/policy/resource-quotas/
- https://github.com/kubernetes-csi/external-snapshotter#setting-quota-limits-with-snapshot-custom-resources

If you have not yet looked at the [Scenario13](../../Scenario13) which talks about CSI Snapshots, you probably have not created a Snapshot Class either.  
Before going through this chapter, follow this step to create such class which is mandatory:

```bash
$ kubectl create -f sc-volumesnapshot.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class created

$ kubectl get volumesnapshotclass
NAME             DRIVER                  DELETIONPOLICY   AGE
csi-snap-class   csi.trident.netapp.io   Delete           3s
```

We are now ready to setup our environment.  
Let's create a new namespace & the snapshot quota:

```bash
$ kubectl create namespace snapshotcontrol
namespace/snapshotcontrol created
$ kubectl create -n snapshotcontrol -f rq-volumesnapshot-limit.yaml
resourcequota/snapshot-quota created

$ kubectl get resourcequota -n snapshotcontrol
NAME             AGE     REQUEST                                              LIMIT
snapshot-quota   2m26s   count/volumesnapshots.snapshot.storage.k8s.io: 0/3
```

We are now going to create a PVC & 3 CSI Snapshots linked to this PVC:

```bash
$ kubectl create -n snapshotcontrol -f pvc-to-snap.yaml
persistentvolumeclaim/pvc-to-snap created

$ kubectl create -n snapshotcontrol -f snapshot-1_2_3.yaml
volumesnapshot.snapshot.storage.k8s.io/snapshot1 created
volumesnapshot.snapshot.storage.k8s.io/snapshot2 created
volumesnapshot.snapshot.storage.k8s.io/snapshot3 created

$ kubectl get -n snapshotcontrol pvc,volumesnapshot
NAME                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/pvc-to-snap   Bound    pvc-d72f2181-5321-4b6a-850e-090d02e75f70   5Gi        RWX            storage-class-nas   17s

NAME                                               READYTOUSE   SOURCEPVC     SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
volumesnapshot.snapshot.storage.k8s.io/snapshot1   true         pvc-to-snap                           268Ki         csi-snap-class   snapcontent-c41d5ff1-19da-4469-b4b0-5b0629c31f0f   8s             8s
volumesnapshot.snapshot.storage.k8s.io/snapshot2   true         pvc-to-snap                           236Ki         csi-snap-class   snapcontent-77127617-e008-495b-a9ec-81d9607247d8   9s             8s
volumesnapshot.snapshot.storage.k8s.io/snapshot3   true         pvc-to-snap                           272Ki         csi-snap-class   snapcontent-40538be0-5038-4dba-83e0-bbdfdad061e9   8s             8s
```

At this point, we have reached the limit set earlier in the scenario.  
Let's see what the quota tells us:

```bash
$ kubectl get resourcequota -n snapshotcontrol
NAME             AGE     REQUEST                                              LIMIT
snapshot-quota   8m41s   count/volumesnapshots.snapshot.storage.k8s.io: 3/3

$ kubectl describe resourcequota -n snapshotcontrol
Name:                                          snapshot-quota
Namespace:                                     snapshotcontrol
Resource                                       Used  Hard
--------                                       ----  ----
count/volumesnapshots.snapshot.storage.k8s.io  3     3
```

Now, what happens when you try to create a new snapshot:

```bash
$ kubectl create -n snapshotcontrol -f snapshot-4.yaml
Error from server (Forbidden): error when creating "snap4.yaml": volumesnapshots.snapshot.storage.k8s.io "snapshot4" is forbidden: exceeded quota: snapshot-quota, requested: count/volumesnapshots.snapshot.storage.k8s.io=1, used: count/volumesnapshots.snapshot.storage.k8s.io=3, limited: count/volumesnapshots.snapshot.storage.k8s.io=3
```

Pretty explicit, right ?!  
We have demonstrated how to use quotas on CSI Snapshots. Time to clean up!

```bash
$ kubectl delete ns snapshotcontrol
namespace "snapshotcontrol" deleted
```

## What's next

You can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp) to choose another scenario.