#########################################################################################
# SCENARIO 13: CSI Snapshots with Ghost
#########################################################################################

This chapter will lead you in the management of snapshots with a blogging application such as Ghost.

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario13_ghost_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 optional parameters, your Docker Hub login & password:  
```bash
sh scenario13_ghost_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create an app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-NAS backend & storage class have already been created. (cf [Scenario02](../../Scenario02)).  
```bash
$ kubectl create -f ghost.yaml
namespace/ghost created
persistentvolumeclaim/mydata created
deployment.apps/blog created
service/blog created

$ kubectl get -n ghost pod,pvc,svc
NAME                       READY   STATUS    RESTARTS   AGE
pod/blog-585566bcd-chndw   1/1     Running   0          43s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-558f5f8c-30f5-4e42-8b85-65dd01d2cfe1   5Gi        RWX            storage-class-nfs   <unset>                 101s

NAME           TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/blog   NodePort   10.96.135.77   <none>        80:30080/TCP   101s
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
192.168.0.131:/trident_pvc_558f5f8c_30f5_4e42_8b85_65dd01d2cfe1
                       5242880       768   5242112   0% /var/lib/ghost/content

$ kubectl exec -n ghost $(kubectl get pod -n ghost -o name) -- ls -l /var/lib/ghost/content/data
total 436
-rw-r--r--    1 node     node        442368 Jul 30 07:34 ghost.db
```

## B. Create a snapshot

We can now proceed with the snapshot creation  
```bash
$ kubectl create -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n ghost
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              840Ki         csi-snap-class   snapcontent-ae2f6a79-5c00-42d1-86a0-d620bb7bbd67   15s            16s

$ tridentctl -n trident get volume
+------------------------------------------+---------+-------------------+----------+--------------------------------------+-------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+-------+---------+
| pvc-558f5f8c-30f5-4e42-8b85-65dd01d2cfe1 | 5.0 GiB | storage-class-nfs | file     | 11d28fb4-6cf5-4c59-931d-94b8d8a5e061 |       | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+-------+---------+


$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+---------+
|                     NAME                      |                  VOLUME                  | MANAGED |
+-----------------------------------------------+------------------------------------------+---------+
| snapshot-ae2f6a79-5c00-42d1-86a0-d620bb7bbd67 | pvc-558f5f8c-30f5-4e42-8b85-65dd01d2cfe1 | true    |
+-----------------------------------------------+------------------------------------------+---------+
```

Your snapshot has been created !  
But what does it translate to at the storage level?  
With ONTAP, you will end up with a *ONTAP Snapshot*, a _ReadOnly_ object, which is instantaneous & space efficient!  
You can see it by browsing through System Manager or connecting with Putty to the _cluster1_ profile (admin/Netapp1!)  
```bash
$ kubectl get pv $( kubectl get pvc mydata -n ghost -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
trident_pvc_558f5f8c_30f5_4e42_8b85_65dd01d2cfe1

$ ssh -l vsadmin 192.168.0.133 vol snaps show -volume trident_pvc_558f5f8c_30f5_4e42_8b85_65dd01d2cfe1
                                                                 ---Blocks---
Vserver  Volume   Snapshot                                  Size Total% Used%
-------- -------- ------------------------------------- -------- ------ -----
nassvm   trident_pvc_558f5f8c_30f5_4e42_8b85_65dd01d2cfe1
                  snapshot-ae2f6a79-5c00-42d1-86a0-d620bb7bbd67 176KB 0%  20%
```

Finally, let's delete the blog content we created earlier.  
- Connect to the website admin page
- Click on your post to edit it
- Click on the _wheel_ at the top right
- At the very bottom of the menu, you will see a button "Delete Post"

There you go, your blog is gone... forever... & ever... & ever (or is it?).  

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
$ kubectl create -f Ghost_clone/1_pvc_from_snap.yaml
persistentvolumeclaim/mydata-from-snap created

$ kubectl get pvc -n ghost
NAME               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata             Bound    pvc-558f5f8c-30f5-4e42-8b85-65dd01d2cfe1   5Gi        RWX            storage-class-nfs   <unset>                 13m
mydata-from-snap   Bound    pvc-c245ac2e-34ca-4d1d-93d1-950b27fc0574   5Gi        RWX            storage-class-nfs   <unset>                 13s
```

Your clone has been created, but what does it translate to at the storage level?  
With ONTAP, you will end up with a *FlexClone*, which is instantaneous & space efficient!  
Said differently,  you can imagine it as a _ReadWrite_ snapshot...  
You can see this object by browsing through System Manager, by connecting with Putty to the _cluster1_ profile (admin/Netapp1!) or other means:  
```bash
$ curl -X GET -ku vsadmin:Netapp1!  "https://192.168.0.133/api/storage/volumes?clone.is_flexclone=true&fields=clone.parent_volume.name,clone.parent_snapshot.name" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "53b8f244-4e47-11ef-afc9-005056b7d7a3",
      "name": "trident_pvc_c245ac2e_34ca_4d1d_93d1_950b27fc0574",
      "clone": {
        "is_flexclone": true,
        "parent_snapshot": {
          "name": "snapshot-ae2f6a79-5c00-42d1-86a0-d620bb7bbd67"
        },
        "parent_volume": {
          "name": "trident_pvc_558f5f8c_30f5_4e42_8b85_65dd01d2cfe1"
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