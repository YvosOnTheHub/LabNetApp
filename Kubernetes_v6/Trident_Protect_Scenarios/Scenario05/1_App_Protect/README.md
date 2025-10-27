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
- an application is a **subset of a namespace** based on _labels_ if you only want to protect part of a namespace (ex: only the PVC)  
- it can span accross **multiple namespaces**  
- last an application can also take into account cluster wide resources  

As the App Owner does not have the credentials to act on the namespace, and since the Kubernetes admin created specific roles in that particular namespace, we will create the application based on labels (**app=busybox**). Only the DEPLOYMENT and its 2 PVC contain that label.  

Let's switch back to App owner impersonation:  
```bash
export KUBECONFIG=/root/.kube/tpsc05-rhel3
```

Creation a Trident Protect application can be achieved through cli or yaml.  
Most of the steps in this scenario are going to be done through cli.  
```bash
$ tridentctl-protect create app bbox --namespaces 'tpsc05busybox(app=busybox)' -n tpsc05busybox
Application "bbox" created.

$ tridentctl-protect get app -n tpsc05busybox
+------+---------------+-------+-----+
| NAME |  NAMESPACES   | STATE | AGE |
+------+---------------+-------+-----+
| bbox | tpsc05busybox | Ready | 13s |
+------+---------------+-------+-----+
```

## B. Snapshot Creation  

Creating an app snapshot consists in 2 steps:  
- create a CSI snapshot per PVC  
- copy the app metadata in the AppVault  
This is potentially done in conjunction with _hooks_ in order to interact with the app. This part is not covered in this chapter.  

Let's create a snapshot:  
```bash
$ tridentctl-protect create snapshot bboxsnap1 --app bbox --appvault ontap-vault -n tpsc05busybox
Snapshot "bboxsnap1" created.

$ tridentctl-protect get snap -n tpsc05busybox
+-----------+------+----------------+-----------+-------+-----+
|   NAME    | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-----------+------+----------------+-----------+-------+-----+
| bboxsnap1 | bbox | Delete         | Completed |       | 11s |
+-----------+------+----------------+-----------+-------+-----+
```

As our app has 2 PVC, you should find 2 Volume Snapshots:  
```bash
$ kubectl get vs
NAME                                                                                     READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
snapshot-fe8ccc56-35a1-4d4d-9105-d0c7e40fb960-pvc-1de7ac03-98cf-4e28-9ccb-a0c7e814c3bb   true         mydata1                             352Ki         csi-snap-class   snapcontent-acf567df-25c9-46ca-9acf-56c852b17b2e   16m            16m
snapshot-fe8ccc56-35a1-4d4d-9105-d0c7e40fb960-pvc-83750f7e-0d88-4e98-aaee-9e50a8a76a4a   true         mydata2                             352Ki         csi-snap-class   snapcontent-6dc3c7af-1083-440d-9691-08d1fb9b3139   16m            16m
```

Browsing through the bucket, you will also find the content of the snapshot (the metadata):  
```bash
$ SNAPPATH=$(kubectl get snapshot bboxsnap1 -o=jsonpath='{.status.appArchivePath}')
$ aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$SNAPPATH --recursive  
2025-06-05 12:59:54       1231 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/application.json
2025-06-05 12:59:54          3 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/exec_hooks.json
2025-06-05 13:00:05       2547 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/post_snapshot_execHooksRun.json
2025-06-05 13:00:00       2570 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/pre_snapshot_execHooksRun.json
2025-06-05 12:59:54       2517 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/resource_backup.json
2025-06-05 12:59:57      13085 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/resource_backup.tar.gz
2025-06-05 12:59:57       6467 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/resource_backup_summary.json
2025-06-05 13:00:05       4643 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/snapshot.json
2025-06-05 13:00:05        682 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/volume_snapshot_classes.json
2025-06-05 13:00:05       3756 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/volume_snapshot_contents.json
2025-06-05 13:00:05       4450 bbox_cf26244e-ecfc-42ef-8ece-3a47908f42f6/snapshots/20250605125955_bboxsnap1_fe8ccc56-35a1-4d4d-9105-d0c7e40fb960/volume_snapshots.json
```

## C. Backup Creation  

Creating an app backup consists in several steps:  
- create an application snapshot if none is specified in the procedure  
- copy the app metadata to the AppVault  
- copy the PVC data to the AppVault
This is also potentially done in conjunction with _hooks_ in order to interact with the app. This part is not covered in this chapter.  
The duration of the backup process takes a bit more time compared to the snapshot, as data is also copied to the bucket.  
```bash
$ tridentctl-protect create backup bboxbkp1 --app bbox --snapshot bboxsnap1 --appvault ontap-vault  -n tpsc05busybox
Backup "bboxbkp1" created.

$ tridentctl-protect get backup -n tpsc05busybox
+----------+------+----------------+-----------+-------+-------+
|   NAME   | APP  | RECLAIM POLICY |   STATE   | ERROR |  AGE  |
+----------+------+----------------+-----------+-------+-------+
| bboxbkp1 | bbox | Retain         | Completed |       | 1m39s |
+----------+------+----------------+-----------+-------+-------+
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

## D. Scheduling  

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

$ tridentctl-protect get schedule -n tpsc05busybox
+-------------+------+--------------------------------+---------+-------+-------+-----+
|    NAME     | APP  |            SCHEDULE            | ENABLED | STATE | ERROR | AGE |
+-------------+------+--------------------------------+---------+-------+-------+-----+
| bbox-sched1 | bbox | DTSTART:20241209T000100Z       | true    |       |       | 28s |
|             |      | RRULE:FREQ=MINUTELY;INTERVAL=5 |         |       |       |     |
+-------------+------+--------------------------------+---------+-------+-------+-----+
```

Now that your application is protected with scheduled snapshots & backups, let's see how you can [restore data](../2_App_Restore/).  