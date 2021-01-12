#########################################################################################
# SCENARIO 13: Kubernetes CSI Snapshots & PVC from Snapshot workflows
#########################################################################################

**GOAL:**  
Kubernetes 1.17 promoted [CSI Snapshots to Beta](https://kubernetes.io/blog/2019/12/09/kubernetes-1-17-feature-cis-volume-snapshot-beta/).  
This is fully supported starting with Trident 20.01.1.  

While snapshots can be used for many use cases, we will see here 2 different ones, which share the same beginning:

- Restore the snapshot in the current application
- Create a new POD which uses a PVC created from the snapshot

There is also a chapter that will show you the impact of deletion between PVC, Snapshots & Clones (spoiler alert: no impact).  

If you have not yet read the [Addenda09](../../Addendum/Addenda09) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario13_pull_images.sh_ you can use in this context to pull images used in this scenario. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario13_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create an app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-NAS backend & storage class have already been created. (cf [Scenario02](../Scenario02)).  

```bash
$ kubectl create namespace ghost
namespace/ghost created

$ kubectl create -n ghost -f ghost.yaml
persistentvolumeclaim/mydata created
deployment.apps/blog created
service/blog created

$ kubectl get all -n ghost
NAME                        READY   STATUS    RESTARTS   AGE
pod/blog-5c9c4cdfbf-q986f   1/1     Running   0          42s

NAME           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/blog   NodePort   10.109.43.212   <none>        80:30080/TCP   42s

NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blog   1/1     1            1           42s

NAME                              DESIRED   CURRENT   READY   AGE
replicaset.apps/blog-5c9c4cdfbf   1         1         1       42s

$ kubectl get pvc,pv -n ghost
NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata   Bound    pvc-d5511709-a2f7-4d40-8f7d-bb3e0cd50316   5Gi        RWX            storage-class-nas   76s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM          STORAGECLASS        REASON   AGE
persistentvolume/pvc-d5511709-a2f7-4d40-8f7d-bb3e0cd50316   5Gi        RWX            Delete           Bound    ghost/mydata   storage-class-nas            73s
```

Because moving on, let's check we can access the app:  
=> http://192.168.0.63:30080

## B. Check the snapshot feature

This [link](https://github.com/kubernetes-csi/external-snapshotter) is a good read if you want to know more details about installing the CSI Snapshotter.  
The **CRD** & **Snapshot-Controller** to enable this feature have already been installed in this cluster. Let's see what we find:

```bash
$ kubectl get crd | grep volumesnapshot
volumesnapshotclasses.snapshot.storage.k8s.io         2020-08-29T21:08:34Z
volumesnapshotcontents.snapshot.storage.k8s.io        2020-08-29T21:08:55Z
volumesnapshots.snapshot.storage.k8s.io               2020-08-29T21:09:13Z

$ kubectl get all -n snapshot-controller
NAME                        READY   STATUS    RESTARTS   AGE
pod/snapshot-controller-0   1/1     Running   0          20h

NAME                                   READY   AGE
statefulset.apps/snapshot-controller   1/1     27d
```

Aside from the 3 CRD & the Controller StatefulSet, the following objects have also been created during the installation of the CSI Snapshot feature:

- serviceaccount/snapshot-controller
- clusterrole.rbac.authorization.k8s.io/snapshot-controller-runner
- clusterrolebinding.rbac.authorization.k8s.io/snapshot-controller-role
- role.rbac.authorization.k8s.io/snapshot-controller-leaderelection
- rolebinding.rbac.authorization.k8s.io/snapshot-controller-leaderelection

Finally, you need to create a _VolumeSnapshotClass_ object that points to the Trident driver.

```bash
$ kubectl create -f sc-volumesnapshot.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class created

$ kubectl get volumesnapshotclass
NAME             DRIVER                  DELETIONPOLICY   AGE
csi-snap-class   csi.trident.netapp.io   Delete           3s
```

Note that the _deletionpolicy_ parameter could also be set to _Retain_.

The _volume snapshot_ feature is now ready to be tested.  

## C. Create a snapshot

Before doing so, let's create a file in our PVC, that will be deleted once the snapshot is created.  
That way, there is a difference between the current filesystem & the snapshot content.  
(obviously, you need to replace the POD name with the one from your environment)  

```bash
$ kubectl exec -n ghost blog-5c9c4cdfbf-q986f -- touch /data/test.txt
$ kubectl exec -n ghost blog-5c9c4cdfbf-q986f -- ls -l /data/test.txt
-rw-r--r--    1 root     root             0 Jun 30 11:34 /data/test.txt
```

Now, we can proceed with the snapshot creation

```bash
$ kubectl create -n ghost -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n ghost
NAME              READYTOUSE   SOURCEPVC      SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                                 5Gi           csi-snap-class   snapcontent-e4ab0f8c-5cd0-4797-a087-0770bd6f1498   25s            54s

$ tridentctl -n trident get volume
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-d5511709-a2f7-4d40-8f7d-bb3e0cd50316 | 5.0 GiB | storage-class-nas | file     | b24a8ae8-a8af-478c-816a-33145116f798 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+
|                     NAME                      |                  VOLUME                  |
+-----------------------------------------------+------------------------------------------+
| snapshot-e4ab0f8c-5cd0-4797-a087-0770bd6f1498 | pvc-d5511709-a2f7-4d40-8f7d-bb3e0cd50316 |
+-----------------------------------------------+------------------------------------------+
```

Your snapshot has been created !  
But what does it translate to at the storage level?  
With ONTAP, you will end up with a *ONTAP Snapshot*, a _ReadOnly_ object, which is instantaneous & space efficient!  
You can see it by browsing through System Manager or connecting with Putty to the _cluster1_ profile (admin/Netapp1!)

```bash
cluster1::> vol snaps show -vserver svm1 -volume nas1_pvc_d5511709_a2f7_4d40_8f7d_bb3e0cd50316
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
svm1     nas1_pvc_d5511709_a2f7_4d40_8f7d_bb3e0cd50316
                  snapshot-e4ab0f8c-5cd0-4797-a087-0770bd6f1498
                                                           156KB     0%   36%
```

Finally, let's delete the file we created earlier.

```bash
kubectl exec -n ghost blog-5c9c4cdfbf-q986f -- rm -f /data/test.txt
```

## D. Create a clone (ie a _PVC from Snapshot_)

Having a snapshot can be useful to create a new PVC.  
If you take a look a the PVC file in the _Ghost/_clone_ directory, you can notice the reference to the snapshot:

```bash
  dataSource:
    name: mydata-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

Let's see how that turns out:

```bash
$ kubectl create -n ghost -f Ghost_clone/1_pvc_from_snap.yaml
persistentvolumeclaim/mydata-from-snap created

$ kubectl get pvc,pv -n ghost
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata             Bound    pvc-d5511709-a2f7-4d40-8f7d-bb3e0cd50316   5Gi        RWX            storage-class-nas   13m
persistentvolumeclaim/mydata-from-snap   Bound    pvc-525c8fff-f48b-4f7a-b5c3-8aa6230ff72f   5Gi        RWX            storage-class-nas   8s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS        REASON   AGE
persistentvolume/pvc-525c8fff-f48b-4f7a-b5c3-8aa6230ff72f   5Gi        RWX            Delete           Bound    ghost/mydata-from-snap   storage-class-nas            7s
persistentvolume/pvc-d5511709-a2f7-4d40-8f7d-bb3e0cd50316   5Gi        RWX            Delete           Bound    ghost/mydata             storage-class-nas            13m
```

Your clone has been created, but what does it translate to at the storage level?  
With ONTAP, you will end up with a *FlexClone*, which is instantaneous & space efficient!  
Said differently,  you can imagine it as a _ReadWrite_ snapshot...  
You can see this object by browsing through System Manager or connecting with Putty to the _cluster1_ profile (admin/Netapp1!)

```bash
cluster1::> vol clone show
                      Parent  Parent        Parent
Vserver FlexClone     Vserver Volume        Snapshot             State     Type
------- ------------- ------- ------------- -------------------- --------- ----
svm1    nas1_pvc_525c8fff_f48b_4f7a_b5c3_8aa6230ff72f
                      svm1    nas1_pvc_d5511709_a2f7_4d40_8f7d_bb3e0cd50316
                                            snapshot-e4ab0f8c-5cd0-4797-a087-0770bd6f1498
                                                                 online    RW
```

This is were you can explore different ways to work with snapshots & clones:  
[1.](1_In_Place_Restore) Restore a snapshot in the first app  
[2.](2_Clone_for_new_app) Launch a new app from the clone  
[3.](3_what_happens_when) Finally, you can see the impacts of deleting some of these objects  
