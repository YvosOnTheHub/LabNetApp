#########################################################################################
# SCENARIO 13: CSI Snapshots with Ghost
#########################################################################################

This chapter will lead you in the management of snapshots with a blogging application such as Ghost.

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario13_ghost_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario13_ghost_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create an app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-NAS backend & storage class have already been created. (cf [Scenario02](../../Scenario02)).  

```bash
$ kubectl create namespace ghost
namespace/ghost created

$ kubectl create -n ghost -f ghost.yaml
persistentvolumeclaim/mydata created
deployment.apps/blog created
service/blog created

$ kubectl get -n ghost pod,pvc,svc
NAME                       READY   STATUS    RESTARTS   AGE
pod/blog-6cbd945df-p8r8t   1/1     Running   0          21s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/mydata   Bound    pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3   5Gi        RWX            storage-class-nas   21s

NAME           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/blog   NodePort   10.103.138.94   <none>        80:30080/TCP   21s
```

Your app is now up & running, let's check we can access the app:  

- `http://192.168.0.63:30080` will display the blog homepage.
- `http://192.168.0.63:30080/ghost` will take you to the admin page

Connect to the _admin_ page. The very first time, you need to create an account in this app.  
The goal of this lab is not to teach how to configure Ghost, so we will just customize the minimum in order to see the benefits.  

I applied two modifications to this website:

- Change the _name_ & _subtitle_ of the website. You can find these in the menu _General_ & then in _Title & description_ (don't forget to save your changes).
- Create a _New Story_. Choose a funny title & some content, and do't forget to click on _Publish_ (top right).

You can see the result by refreshing the blog homepage (`http://192.168.0.63:30080`).  
The content of the blog is written on the PVC.

```bash
$ kubectl exec -n ghost $(kubectl get pod -n ghost -o name) -- df /var/lib/ghost/content
Filesystem           1K-blocks      Used Available Use% Mounted on
192.168.0.135:/nas1_pvc_f2c671b5_26e3_4a6d_9344_4a2083a611a3
                       4980736       768   4979968   0% /var/lib/ghost/content

$ kubectl exec -n ghost $(kubectl get pod -n ghost -o name) -- ls -l /var/lib/ghost/content/data
total 436
-rw-r--r--    1 node     node        442368 Jun 17 14:16 ghost.db
```

## B. Create a snapshot

We can now proceed with the snapshot creation

```bash
$ kubectl create -n ghost -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n ghost
NAME              READYTOUSE   SOURCEPVC      SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                                 5Gi           csi-snap-class   snapcontent-3a286486-7a69-499d-b9d7-163e3f62892c   25s            54s

$ tridentctl -n trident get volume
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3 | 5.0 GiB | storage-class-nas | file     | 7a7553c7-ddce-4c44-9325-04cd1e136dc5 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+
|                     NAME                      |                  VOLUME                  |
+-----------------------------------------------+------------------------------------------+
| snapshot-3a286486-7a69-499d-b9d7-163e3f62892c | pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3 |
+-----------------------------------------------+------------------------------------------+
```

Your snapshot has been created !  
But what does it translate to at the storage level?  
With ONTAP, you will end up with a *ONTAP Snapshot*, a _ReadOnly_ object, which is instantaneous & space efficient!  
You can see it by browsing through System Manager or connecting with Putty to the _cluster1_ profile (admin/Netapp1!)

```bash
$ kubectl get pv $( kubectl get pvc mydata -n ghost -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
nas1_pvc_f2c671b5_26e3_4a6d_9344_4a2083a611a3

$ ssh -l vsadmin 192.168.0.135 vol snaps show -volume nas1_pvc_f2c671b5_26e3_4a6d_9344_4a2083a611a3

cluster1::> vol snaps show -vserver nfs_svm -volume nas1_pvc_d5511709_a2f7_4d40_8f7d_bb3e0cd50316
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
nfs_svm  nas1_pvc_f2c671b5_26e3_4a6d_9344_4a2083a611a3
                  snapshot-3a286486-7a69-499d-b9d7-163e3f62892c 168KB 0%  19%
                  hourly.2021-06-17_1505                   136KB     0%   16%
2 entries were displayed.
```

Finally, let's delete the blog content we created earlier.  

- Connect to the website admin page
- Click on your post to edit it
- Click on the _wheel_ at the top right
- At the very bottom of the menu, you will see a button "Delete Post"

There you go, your blog is gone... forever... & ever... & ever.

## C. Create a clone (ie a _PVC from Snapshot_)

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
persistentvolumeclaim/mydata             Bound    pvc-f2c671b5-26e3-4a6d-9344-4a2083a611a3   5Gi        RWX            storage-class-nas   13m
persistentvolumeclaim/mydata-from-snap   Bound    pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            storage-class-nas   8s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS        REASON   AGE
persistentvolume/pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            Delete           Bound    ghost/mydata-from-snap   storage-class-nas            7s
persistentvolume/pvc-a7c8be57-73a3-43dc-b268-23e43c7a82fc   5Gi        RWX            Delete           Bound    ghost/mydata             storage-class-nas            13m
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
      "uuid": "43307846-cf81-11eb-83c4-005056b03185",
      "name": "nas1_pvc_a7c8be57_73a3_43dc_b268_23e43c7a82fc",
      "clone": {
        "is_flexclone": true,
        "parent_snapshot": {
          "name": "snapshot-3a286486-7a69-499d-b9d7-163e3f62892c"
        },
        "parent_volume": {
          "name": "nas1_pvc_f2c671b5_26e3_4a6d_9344_4a2083a611a3"
        }
      }
    }
  ],
  "num_records": 1
}
```

This is were you can explore different ways to work with snapshots & clones:  
[1.](1_In_Place_Restore) Restore a snapshot in the first app  
[2.](2_Clone_for_new_app) Launch a new app from the clone  
[3.](3_what_happens_when) Finally, you can see the impacts of deleting some of these objects  