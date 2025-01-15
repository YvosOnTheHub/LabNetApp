#########################################################################################
# SCENARIO 5: Tests scenario with Busybox: Application Protection
#########################################################################################  

This chapter will guide you through the creation of:  
- a Trident Protect application  
- an AppVault to store the metadata & the backups  
- a manual snapshot  
- a manual backup  
- the schedule to automatically run snapshots & backups  

## A. Application Creation  

Before going any further, what is an application?  
There are various way to define that in Kubernetes. Trident Protect can manage the following configurations:  
- an application is a **namespace** and everything that is part of the namespace must be protected  
- an application is a **subset of a namespace** based on labels if you only want to protect part of a namespace (ex: only the PVC)  
- it can span accross **multiple namespaces**  
- last an application can also take into account cluster wide resources  

In this scenario, we consider that the application to protect is the whole _bbox_ namespace.  

Creation a Trident Protect application can be achieved through cli or yaml. Most of the steps in this scenario are going to be done through cli.  
```bash
$ tridentctl protect create app bbox --namespaces tpsc05busybox -n tpsc05busybox
Application "bbox" created.

$ tridentctl protect get app -n tpsc05busybox
+------+---------------+-------+-----+
| NAME |  NAMESPACES   | STATE | AGE |
+------+---------------+-------+-----+
| bbox | tpsc05busybox | Ready | 13s |
+------+---------------+-------+-----+
```

## B. AppVault  

If you have not yet created an AppVault, refer to the [Scenario03](../../Scenario03/) which guides you through the bucket provisioning as well as the AppVault (_ontap-vault_), which is created in the Trident Protect namespace, by the admin.  
This AppVault should be present on both Kubernetes clusters.  

## C. Snapshot Creation  

Creating an app snapshot consists in 2 steps:  
- create a CSI snapshot per PVC  
- copy the app metadata in the AppVault  
This is potentially done in conjunction with _hooks_ in order to interact with the app. This part is not covered in this chapter.  

Let's create a snapshot:  
```bash
$ tridentctl protect create snapshot bboxsnap1 --app bbox --appvault ontap-vault -n tpsc05busybox
Snapshot "bboxsnap1" created.

$ tridentctl protect get snap -n tpsc05busybox
+-----------+---------+-----------+-----+-------+
|   NAME    | APP REF |   STATE   | AGE | ERROR |
+-----------+---------+-----------+-----+-------+
| bboxsnap1 | bbox    | Completed | 11s |       |
+-----------+---------+-----------+-----+-------+
```

As our app has 2 PVC, you should find 2 Volume Snapshots:  
```bash
$ kubectl get -n tpsc05busybox vs
NAME                                                                                     READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
snapshot-3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf-pvc-93859da5-107d-4b08-9ca3-e8533c226852   true         mydata1                             268Ki         csi-snap-class   snapcontent-23d2d6a5-18fe-4ec5-a0ec-d33e5056e4a2   37s            37s
snapshot-3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf-pvc-b09001f8-8b57-4863-b275-961de4edb2ad   true         mydata2                             268Ki         csi-snap-class   snapcontent-3314f7b0-0871-4200-83a6-c2d009621fdc   37s            37s
```

Browsing through the bucket, you will also find the content of the snapshot (the metadata):  
```bash
$ SNAPPATH=$(kubectl -n tpsc05busybox get snapshot bboxsnap1 -o=jsonpath='{.status.appArchivePath}')
$ aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$SNAPPATH --recursive  
2025-01-06 07:23:19       1230 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/application.json
2025-01-06 07:23:19          3 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/exec_hooks.json
2025-01-06 07:23:30       2496 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/post_snapshot_execHooksRun.json
2025-01-06 07:23:24       2494 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/pre_snapshot_execHooksRun.json
2025-01-06 07:23:19       2474 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/resource_backup.json
2025-01-06 07:23:22      12321 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/resource_backup.tar.gz
2025-01-06 07:23:22       6137 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/resource_backup_summary.json
2025-01-06 07:23:30       4181 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/snapshot.json
2025-01-06 07:23:30        682 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/volume_snapshot_classes.json
2025-01-06 07:23:30       3752 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/volume_snapshot_contents.json
2025-01-06 07:23:30       4440 bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/snapshots/20250106072320_bboxsnap1_3ac0a87e-fb01-4c3a-97f2-13ec740f7dbf/volume_snapshots.json
```

## D. Backup Creation  

Creating an app backup consists in several steps:  
- create an application snapshot if none is specified in the procedure  
- copy the app metadata to the AppVault  
- copy the PVC data to the AppVault
This is also potentially done in conjunction with _hooks_ in order to interact with the app. This part is not covered in this chapter.  
The duration of the backup process takes a bit more time compared to the snapshot, as data is also copied to the bucket.  
```bash
$ tridentctl protect create backup bboxbkp1 --app bbox --snapshot bboxsnap1 --appvault ontap-vault  -n tpsc05busybox
Backup "bboxbkp1" created.

$ tridentctl protect get backup -n tpsc05busybox
+----------+---------+-----------+-------+-------+
|   NAME   | APP REF |   STATE   |  AGE  | ERROR |
+----------+---------+-----------+-------+-------+
| bboxbkp1 | bbox    | Completed | 1m15s |       |
+----------+---------+-----------+-------+-------+
```
If you check the bucket, you will see more subfolders appear:  
```bash
$ APPPATH=$(echo $SNAPPATH | awk -F '/' '{print $1}')
$ aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$APPPATH/
                           PRE backups/
                           PRE kopia/
                           PRE snapshots/
```
The *backups* folder contains the app metadata, while the *kopia* one contains the data.  

## E. Scheduling  

Creating a schedule to automatically take snapshots & backups can also be done with the cli.  
Update frequencies can be chosen between _hourly_, _daily_, _weekly_ & _monthly_.  
For this lab, in order to witness scheduled snapshots & backups, it is probably better to move to a faster frequency, done with _custom_ granularity.  
This this example, let's switch to YAML:  
```bash
$ cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: Schedule
metadata:
  name: bbox-sched1
  namespace: tpsc05busybox
spec:
  appVaultRef: ontap-vault
  applicationRef: bbox
  backupRetention: "3"
  dataMover: Kopia
  enabled: true
  granularity: Custom
  recurrenceRule: |-
    DTSTART:20250106T000100Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  snapshotRetention: "3"
EOF
schedule.protect.trident.netapp.io/bbox-sched1 created

$ tridentctl protect get schedule -n tpsc05busybox
+-------------+------+--------------------------------+---------+-------+-----+-------+
|    NAME     | APP  |            SCHEDULE            | ENABLED | STATE | AGE | ERROR |
+-------------+------+--------------------------------+---------+-------+-----+-------+
| bbox-sched1 | bbox | DTSTART:20241209T000100Z       | true    |       | 28s |       |
|             |      | RRULE:FREQ=MINUTELY;INTERVAL=5 |         |       |     |       |
+-------------+------+--------------------------------+---------+-------+-----+-------+
```

Now that your application is protected with scheduled snapshots & backups, let's see how you can [restore data](../2_App_Restore/).  