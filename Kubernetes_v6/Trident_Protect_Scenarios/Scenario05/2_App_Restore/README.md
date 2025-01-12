#########################################################################################
# SCENARIO 5: Tests scenario with Busybox: Application Restore
#########################################################################################  

When restoring applications with Trident Protect, you can achieve the following:
- Restore from a snapshot  
-- in-place or to a new namespace  
-- full or partial  
- Restore from a backup
-- in-place or to a new namespace  
-- on the same Kubernetes cluster or a different one  
-- full or partial  

Let's into all those possibilities:  

## A. In-place partial snapshot restore  

Let's first delete the content of one of the 2 volumes mounted on the pod (_data1_).  
```bash
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- rm -f /data1/file.txt
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- ls /data1/
```

tridentctl protect create sir bboxsir1 --snapshot tpsc05busybox/bboxsnap1 --resource-filter-include='[{"kind":"PersistentVolumeClaim"},{"names":["mydata1"]}]' -n tpsc05busybox
>

tridentctl protect create sir bboxsir1 --snapshot tpsc05busybox/bboxsnap1 --resource-filter-include='[{"labelSelectors":["volume=mydata1"]}]' -n tpsc05busybox

tridentctl protect get sir -n bbox; kubectl -n bbox get pod,pvc

# check result
kubectl exec -n bbox $(kubectl get pod -n bbox -o name) -- ls /data/
kubectl exec -n bbox $(kubectl get pod -n bbox -o name) -- more /data/test.txt


cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: SnapshotInplaceRestore
metadata:
  name: bboxsir2
  namespace: tpsc05busybox
spec:
  appArchivePath: bbox_c86f3be1-5e49-4fb4-a1da-b0d356d81274/snapshots/20241211091052_bboxsnap1_eeaa2137-ddb2-4fb5-808a-21bf3e2a2397
  appVaultRef: ontap-vault
  resourceFilter:
    resourceSelectionCriteria: "Include"
    resourceMatchers:
    - labelSelectors: [volume=mydata1]
    
EOF



## B. Full snapshot restore to a new namespace  

Now, let's restore our snapshot to a different namespace.  
In this context, you need to specify the mapping for the application namespace:  
```bash
$ tridentctl protect create sr bboxsr1 --namespace-mapping tpsc05busybox:tpsc05busyboxsr --snapshot tpsc05busybox/bboxsnap1 -n tpsc05busyboxsr
SnapshotRestore "bboxsr1" created.

$ tridentctl protect get sr -n tpsc05busyboxsr
+---------+---------------+-----------+-----+-------+
|  NAME   |    APPVAULT   |   STATE   | AGE | ERROR |
+---------+---------------+-----------+-----+-------+
| bboxsr1 |  ontap-vault  | Completed | 14s |       |
+---------+---------------+-----------+-----+-------+

$ kubectl -n tpsc05busyboxsr get pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-w65pf   1/1     Running   0          24s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-fae1f064-3320-4f41-acfb-5470a4b2c814   1Gi        RWX            storage-class-nfs   <unset>                 25s
persistentvolumeclaim/mydata2   Bound    pvc-8ab297b7-1624-4f5d-910c-2c8a1f4b80b5   1Gi        RWX            storage-class-nfs   <unset>                 25s
```
The application is quickly available on the target namespace.  
Just to make sure, let's read the content of the volumes:  
```bash
$ kubectl exec -n tpsc05busyboxsr $(kubectl get pod -n tpsc05busyboxsr -o name) -- more /data1/file.txt
bbox test1 in folder data1!
$ kubectl exec -n tpsc05busyboxsr $(kubectl get pod -n tpsc05busyboxsr -o name) -- more /data2/file.txt
bbox test1 in folder data2!
```

## C. In-place backup restore  

For this test, let's first delete the POD & the 2 PVC from the namespace:  
```bash
kubectl delete -n tpsc05busybox deploy busybox
kubectl delete -n tpsc05busybox pvc --all
```
=> "Ohlalalalalala, I deleted my whole app! what can I do?!"  

Easy answer, you restore everything from a backup...  
Let's see that in action:  
```bash
$ tridentctl protect create bir bboxbir1 --backup tpsc05busybox/bboxbkp1 -n tpsc05busybox
BackupInplaceRestore "bboxbir1" created.

$ tridentctl protect get bir -n tpsc05busybox
+----------+-------------+-----------+------+-------+
|   NAME   |   APPVAULT  |   STATE   | AGE  | ERROR |
+----------+-------------+-----------+------+-------+
| bboxbir1 | ontap-vault | Completed | 1m1s |       |
+----------+-------------+-----------+------+-------+

$ kubectl -n tpsc05busybox get po,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-xf5df   1/1     Running   0          16s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-5d0d41b8-9b7e-4895-a530-76d4c02d1f29   1Gi        RWX            storage-class-nfs   <unset>                 17s
persistentvolumeclaim/mydata2   Bound    pvc-22302af7-8872-4598-b789-47a6fd025b37   1Gi        RWX            storage-class-nfs   <unset>                 17s
```
Our app is back, but what about the data:  
```bash
$ kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- more /data1/file.txt
bbox test1 in folder data1!
$ kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- more /data2/file.txt
bbox test1 in folder data2!
```

## D. Backup restore to the secondary Kubernetes cluster  

Last test of this chapter consists into restoring the whole app on the secondary cluster.  
Make sure an AppVault on the secondary cluster exists, so that you get access to the content of the bucket.  
If you have not yet created an AppVault, refer to the [Scenario03](../../Scenario03/).  

The following commands must be performed on the _RHEL5_ host:  
```bash
$ tridentctl protect get appvault ontap-vault -n trident-protect
+--------------+----------+-----------+-----+-------+
|     NAME     | PROVIDER |   STATE   | AGE | ERROR |
+--------------+----------+-----------+-----+-------+
|  ontap-vault | OntapS3  | Available | 21s |       |
+--------------+----------+-----------+-----+-------+
```

Tridentctl includes a flag that helps you browse through an AppVault.  
This can be useful when restoring to a cluster different from the source, especially when the source is totally gone...  
```bash
$ tridentctl protect get appvaultcontent ontap-vault --show-resources all -n trident-protect
+---------+------+----------+-----------------------------+---------------------------+
| CLUSTER | APP  |   TYPE   |            NAME             |         TIMESTAMP         |
+---------+------+----------+-----------------------------+---------------------------+
| lod1    | bbox | backup   | bkp1                        | 2025-01-05 09:50:20 (UTC) |
| lod1    | bbox | snapshot | bboxsnap1                   | 2025-01-06 07:23:30 (UTC) |
| lod1    | bbox | snapshot | custom-64aea-20250106073100 | 2025-01-06 07:31:10 (UTC) |
| lod1    | bbox | snapshot | custom-64aea-20250106073600 | 2025-01-06 07:36:11 (UTC) |
| lod1    | bbox | snapshot | custom-64aea-20250106074100 | 2025-01-06 07:41:10 (UTC) |
| lod1    | bbox | backup   | bboxbkp1                    | 2025-01-06 07:26:23 (UTC) |
| lod1    | bbox | backup   | custom-64aea-20250106073100 | 2025-01-06 07:32:29 (UTC) |
| lod1    | bbox | backup   | custom-64aea-20250106073600 | 2025-01-06 07:37:34 (UTC) |
| lod1    | bbox | backup   | custom-64aea-20250106074100 | 2025-01-06 07:42:32 (UTC) |
+---------+------+----------+-----------------------------+---------------------------+
```
As expected, you can see in the list:  
- the manual snapshot and backup
- the scheduled snapshots and backups (3 of each)  

Let's restore from the manual backup. We also need to gather the full path for this step (see the *--show-paths* flag):  
```bash
$ tridentctl protect get appvaultcontent ontap-vault --app bbox --show-resources backup --show-paths -n trident-protect
+---------+------+--------+-----------------------------+---------------------------+--------------------------------------------------------------------------------------------------------------------+
| CLUSTER | APP  |  TYPE  |            NAME             |         TIMESTAMP         |                                                        PATH                                                        |
+---------+------+--------+-----------------------------+---------------------------+--------------------------------------------------------------------------------------------------------------------+
| lod1    | bbox | backup | bkp1                        | 2025-01-05 09:50:20 (UTC) | bbox_c622fc58-5bcc-43dd-a139-ccc548551c08/backups/bkp1_6c9a7f14-5b21-46c7-a057-4e9d134c5086                        |
| lod1    | bbox | backup | bboxbkp1                    | 2025-01-06 07:26:23 (UTC) | bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/backups/bboxbkp1_b72088d5-65c3-45b3-a690-3dee53daa841                    |
| lod1    | bbox | backup | custom-64aea-20250106073100 | 2025-01-06 07:32:29 (UTC) | bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/backups/custom-64aea-20250106073100_3c64a456-60df-4042-aa53-d3b67139467e |
| lod1    | bbox | backup | custom-64aea-20250106073600 | 2025-01-06 07:37:34 (UTC) | bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/backups/custom-64aea-20250106073600_d53bfda7-6dd8-4602-8f74-cc97524cb187 |
| lod1    | bbox | backup | custom-64aea-20250106074100 | 2025-01-06 07:42:32 (UTC) | bbox_c72389d7-813e-4ec4-ab1b-ebe002c53599/backups/custom-64aea-20250106074100_1b9edbc4-d933-436f-871f-24b73dd72dbd |
+---------+------+--------+-----------------------------+---------------------------+--------------------------------------------------------------------------------------------------------------------+
```

You can use the following command to retrieve the path of the manual backup:  
```bash
BKPPATH=$(tridentctl protect get appvaultcontent ontap-vault --app bbox --show-resources backup --show-paths -n trident-protect | grep bboxbkp1  | awk -F '|' '{print $7}')
```
Let's proceed with the restore operation and check the result after a few seconds.  
Notice that you also add a mapping for storage classes.  
```bash
$ tridentctl protect create br bboxbr1 --namespace-mapping tpsc05busybox:tpsc05busyboxbr --appvault ontap-vault -n tpsc05busyboxbr \
  --storageclass-mapping storage-class-nfs:sc-nfs \
  --path $BKPPATH
BackupRestore "bboxbr1" created.

$ tridentctl protect get br -n tpsc05busyboxbr
+---------+---------------+-----------+-----+-------+
|  NAME   |    APPVAULT   |   STATE   | AGE | ERROR |
+---------+---------------+-----------+-----+-------+
| bboxbr1 |  ontap-vault  | Completed | 48s |       |
+---------+---------------+-----------+-----+-------+

$ kubectl -n tpsc05busyboxbr get pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-lqvkc   1/1     Running   0          20s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-f96b7e21-cf40-414b-b712-a594d99ea4e0   1Gi        RWX            sc-nfs         <unset>                 24s
persistentvolumeclaim/mydata2   Bound    pvc-319180b9-f5b1-41f0-bcc5-4e87efb98975   1Gi        RWX            sc-nfs         <unset>                 24s
```
Now that the app is back, let's check the content of the volumes:  
```bash
$ kubectl exec -n tpsc05busyboxbr $(kubectl get pod -n tpsc05busyboxbr -o name) -- more /data1/file.txt
bbox test1 in folder data1!
$ kubectl exec -n tpsc05busyboxbr $(kubectl get pod -n tpsc05busyboxbr -o name) -- more /data2/file.txt
bbox test1 in folder data2!
```

Tadaaa!

Next chapter, let's see how to put in a place a [Disaster Recovery plan](../3_App_Disaster_Recovery_Plan/).
