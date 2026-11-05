#########################################################################################
# SCENARIO 29: Both mechanisms on ontap-san-economy
#########################################################################################

[1. Trident Autogrow Policy](../1-autogrow-policy) grows the PVC.  
[2. ONTAP volume autosize](../2-ontap-volume-autosize) grows the FlexVol and leaves the PVC alone.  

This chapter turns both on, for the whole exercise, on one `ontap-san-economy` pool.  
Two BusyBox claims share that FlexVol. You write, take a snapshot, delete, and trim, and after each step you read two sizes: the PVC capacity, and the FlexVol size ONTAP reports. `df` inside the pod is the third number, the filesystem the application can actually fill.

The limits are what make the two mechanisms take turns:

| | Trident Autogrow Policy `s29-both` | ONTAP volume autosize |
| :--- | :--- | :--- |
| Threshold | 80% of that PVC | 60% of the FlexVol |
| Growth | 1Gi, then stop | up to 50% above the size Trident last set |
| Ceiling | `maxSize: 2Gi` | `maximumSize: 50%` |

A 1Gi filesystem that crosses 80% is grown to 2Gi. That is the only step the policy can take, because 2Gi is the ceiling.  
Trident then enlarges the shared FlexVol by about that same 1Gi, so the larger LUN still fits. That growth belongs to the resize, and it drops the FlexVol used percentage back under 60%.  
The later write stays under 80% of the new filesystem, so the claims stay where they are, and the blocks a snapshot is holding push the FlexVol through 60%. That growth is autosize.

| What you see | Who moved it |
| :--- | :--- |
| PVC capacity changes, and the FlexVol grows by about the same amount | Autogrow, then Trident fitting the larger LUN into the pool |
| A new empty PVC appears and the FlexVol grows by about 1Gi | Trident placing another LUN |
| The FlexVol grows by a fraction of a gigabyte and both claims stay put | ONTAP autosize |
| `df` drops and the FlexVol used space stays | A delete, before any trim, or a snapshot still holding the blocks |

Every application uses `registry.demo.netapp.com/busybox:1.35.0`.  
If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
The pull script for this image sits in the parent directory:

```bash
sh ../scenario29_pull_images.sh
```

Run the commands from this folder.  
The command output in this chapter is illustrative. It was not captured from a run. Names will differ. The sizes are the ones these write counts should produce, give or take a few hundredths.

## A. Policy, backend, storage class

Autosize is a backend setting. `storagePrefix: san_eco_both_` gives this demo FlexVols of its own, so the policy cannot rewrite the pools from [Scenario05](../../Scenario05) or from the previous folder.  
`maximumSize` has to be a percentage on `ontap-san-economy`. `50%` means the FlexVol may grow to 1.5 times the size it has when Trident writes the setting.  
The storage class pins the pool to `aggr1`, so both LUNs land in one FlexVol.  
`spaceAllocation: "true"` tells ONTAP to advertise UNMAP on those LUNs. There is no `discard` mount option: the previous chapter mounts with `discard`, which unmaps blocks at delete time. Leaving it off keeps the delete and the trim as two readings.  
`allowVolumeExpansion: true` is required by the autogrow policy. The annotation on the storage class attaches `s29-both` to every PVC this class creates.

The snapshot class is the one from [Scenario13](../../Scenario13/1_CSI_Snapshots). Create it only if it is not already there:

```bash
$ kubectl get volumesnapshotclass csi-snap-class >/dev/null 2>&1 || kubectl create -f sc-volumesnapshot.yaml

$ kubectl create -f autogrow-policy.yaml -f backend-iscsi-eco-both.yaml -f sc-iscsi-eco-both.yaml
tridentautogrowpolicy.trident.netapp.io/s29-both created
tridentbackendconfig.trident.netapp.io/backend-iscsi-eco-both created
storageclass.storage.k8s.io/storage-class-iscsi-economy-both created

$ kubectl get tap s29-both -o wide
NAME       USED THRESHOLD   GROWTH AMOUNT   MAX SIZE   STATE     MESSAGE
s29-both   80%              1Gi             2Gi        Success   Autogrow policy validated and ready to use

$ kubectl get -n trident tbc backend-iscsi-eco-both
NAME                     BACKEND NAME            BACKEND UUID                           PHASE   STATUS
backend-iscsi-eco-both   BackendForiSCSIEcoBoth  4c1e0a2b-7b31-4d0e-9a11-0b5e8c2a11d4   Bound   Success
```

`PHASE` should be `Bound` and `STATUS` should be `Success` before you create a PVC.

## B. Two PVCs, one FlexVol

Create the first claim and read the FlexVol before the second LUN exists. On this driver `internalName` is the LUN. The FlexVol name is the 5th field of `internalID`.

```bash
$ kubectl create -f busybox.yaml
namespace/s29-both created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n s29-both pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-8rx9w   1/1     Running   0          25s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 25s
```

```bash
$ PV=$(kubectl get pvc -n s29-both mydata -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV -o jsonpath='{.config.ontapAutosizeMode} {.config.ontapAutosizeGrowThresholdPercent} {.config.ontapAutosizeMaximumSize}'; echo
grow 60 50%

$ VOLNAME=$(kubectl get -n trident tvol $PV -o=jsonpath='{.config.internalID}' | cut -d/ -f5)
$ echo $VOLNAME
trident_lun_pool_san_eco_both_K7NQWMPXAR

$ VOLUUID=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid')
$ s29_ontap() {
  curl -s -ku admin:Netapp1! -H "accept: application/json" \
    "https://cluster1.demo.netapp.com/api/storage/volumes/${VOLUUID}?fields=name,space.size,space.used,autosize" \
    | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
}
$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 1,
  "used_gb": 0.03,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 1.5
}
```

`mode` is `grow`. `size_gb` is 1, the first LUN and nothing else. Keep `s29_ontap` in this shell. In a new shell, set `VOLUUID` again and paste the function again.

The second claim is a different event. Trident places another 1Gi LUN in the same FlexVol and resizes that FlexVol to the sum of the LUNs. No data is written. Autosize is not involved: used space is still almost empty.

```bash
$ kubectl create -f busybox2.yaml
persistentvolumeclaim/mydata2 created
deployment.apps/busybox2 created

$ kubectl get -n s29-both pod,pvc
NAME                            READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-8rx9w    1/1     Running   0          2m
pod/busybox2-8679459f5-b7jwj    1/1     Running   0          15s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata    Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 2m
persistentvolumeclaim/mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 15s
```

Both LUNs should name the same FlexVol:

```bash
$ PV2=$(kubectl get pvc -n s29-both mydata2 -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV2 -o=jsonpath='{.config.internalID}' | cut -d/ -f5
trident_lun_pool_san_eco_both_K7NQWMPXAR

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
2

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 2,
  "used_gb": 0.05,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 3
}
```

`size_gb` is 2. `max_gb` moved with it: Trident rewrites the 50% ceiling when it resizes the pool. Both claims are 1Gi. The policy is attached to both, which you can see from the volume count:

```bash
$ tridentctl -n trident get agp
+----------+----------------+---------------+----------+---------+
|   NAME   | USED THRESHOLD | GROWTH AMOUNT | MAX SIZE | VOLUMES |
+----------+----------------+---------------+----------+---------+
| s29-both | 80%            | 1Gi           | 2Gi      |       2 |
+----------+----------------+---------------+----------+---------+
```

From here, these two commands are the filesystem side of the same reading. `df` on `busybox` is `mydata`. `df` on `busybox2` is `mydata2`.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767174
                        973.4M     24.0K    906.2M   0% /data

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767231
                        973.4M     24.0K    906.2M   0% /data
```

## C. A write that grows the PVC

`/dev/urandom` matters. A stream of zeroes would be swallowed by compression and the FlexVol used space would barely move.  
850Mi is about 87% of the 973Mi filesystem, which is past the 80% autogrow threshold. It is about 43% of the 2Gi FlexVol, which is under the 60% autosize threshold.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=850'
```

Read the FlexVol immediately. `size_gb` is still 2. `used_gb` has climbed. The PVC is still 1Gi: Trident checks about once a minute.

```bash
$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 2,
  "used_gb": 0.86,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 3
}

$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 4m
mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 2m
```

A LUN resize is slow enough that you can often catch the request Trident raises for it:

```bash
$ kubectl get tagri -n trident
NAME                                             VOLUME                                     AUTOGROW POLICY   OBSERVED USED%   OBSERVED CAPACITY   FINAL SIZE    PHASE        AGE
tagri-pvc-e5f85851-f07e-43d5-ac38-f032133cd311   pvc-e5f85851-f07e-43d5-ac38-f032133cd311   s29-both          87.1             1046898278          2147483648    InProgress   8s
```

About a minute after the write, `mydata` is 2Gi. `mydata2` is still 1Gi. The policy is per PVC: the neighbor's filesystem is empty, so that claim stays.

```bash
$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 6m
mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 4m

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767174
                          1.9G    850.1M    978.2M  46% /data

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3,
  "used_gb": 0.88,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

The filesystem was extended while the pod kept running. `size_gb` went from 2 to 3, one gigabyte, the amount the LUN grew. `max_gb` was recalculated against that new size. Used space is about 0.88Gi on a 3Gi FlexVol, near 30%, so autosize has nothing to do.  
Wait until `mydata` shows 2Gi before the next write. While the FlexVol is still 2Gi, the next write can push used space through 60% and the two mechanisms move in the same minute.

## D. A smaller write on the neighbor

500Mi is about half of the 1Gi filesystem on `mydata2`, under the 80% autogrow threshold. Added to the 0.88Gi already in the pool, it is under 60% of the 3Gi FlexVol.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=500'
```

Give it a minute, then read both sides. Nothing has authority to grow.

```bash
$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 8m
mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 6m

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3,
  "used_gb": 1.39,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

`size_gb` is 3. Both capacities are the ones autogrow already settled. `used_gb` is the 850Mi plus the 500Mi.

## E. Snapshot

On `ontap-san-economy` a VolumeSnapshot is a LUN clone in this same FlexVol. A FlexVol snapshot would capture every LUN in the pool, so Trident clones only the LUN behind `mydata`. Creating it shares the existing blocks. `used_gb` barely moves, and neither ceiling is involved.

```bash
$ kubectl create -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n s29-both
NAME               READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot    true         mydata                              2Gi           csi-snap-class   snapcontent-7eb61014-465a-4048-a1cb-4d57b078bebd   20s            21s

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
3

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3,
  "used_gb": 1.39,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

The LUN count went from 2 to 3. The third LUN is the clone. `size_gb` is still 3, and both claims are still 2Gi and 1Gi. The cost of this snapshot shows up at the next delete.

## F. Delete

Remove the file on both pods. `df` recovers. The LUNs still own the blocks: nothing has sent UNMAP, and the clone of `mydata` needs its blocks anyway.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- rm -f /data/random
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- rm -f /data/random

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767174
                          1.9G     24.0K      1.8G   0% /data

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767231
                        973.4M     24.0K    906.2M   0% /data

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3,
  "used_gb": 1.39,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

Both filesystems are empty. `used_gb` is still about 1.39. The claims are still 2Gi and 1Gi. Autogrow watches a filesystem that just emptied, so it stays quiet. Autosize does not shrink.

## G. Trim

`trim.sh` runs `fstrim -v /data` from the BusyBox image. That image already contains `fstrim`. The volume is not mounted with `discard`, so the unmap has to be asked for. The FITRIM ioctl needs `CAP_SYS_ADMIN`, which the application pods do not have, so the script starts a short-lived pod with that capability only. The pod mounts the same claim and is pinned to the node that already has it, which is what a `ReadWriteOnce` volume allows.

Trim `mydata2` first. Nothing snapshots that LUN, so ONTAP can return those blocks.

```bash
$ bash trim.sh s29-both busybox2 mydata2
trimming mydata2 on rhel1
/data: 500.1 MiB (524392448 bytes) trimmed

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3,
  "used_gb": 0.88,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

`used_gb` fell by about the 500Mi. `size_gb` is still 3. The PVC capacities are still 2Gi and 1Gi.

Trim `mydata` next. `fstrim` runs, and the clone still references the 850Mi. UNMAP does not free a block a snapshot needs.

```bash
$ bash trim.sh s29-both busybox mydata
trimming mydata on rhel1
/data: 850.1 MiB (891234560 bytes) trimmed

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3,
  "used_gb": 0.88,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

`used_gb` is still about 0.88. The guest discarded the free space of `mydata`. The LUN clone kept the blocks, inside the FlexVol `mydata2` also lives on. One PVC's snapshot is sitting in the pool both claims share.

## H. A write that grows the FlexVol

`mydata` is a 2Gi claim, and 2Gi is `maxSize`. Another 1200Mi fills about 63% of that filesystem, under the 80% autogrow threshold, so the policy has nothing to add and no room above the ceiling anyway.  
Those 1200Mi are new blocks. The clone still holds the old 850Mi. Together that is about 2.05Gi on a 3Gi FlexVol, about 68%, past the 60% autosize threshold. The write itself fits in the 3Gi, so it can finish, and ONTAP grows the FlexVol afterwards. Give it a few seconds.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=1200'

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3.42,
  "used_gb": 2.05,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}

$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 20m
mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 18m

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767174
                          1.9G      1.2G    678.0M  64% /data
```

`size_gb` is about 3.42, just large enough that `used_gb` sits under 60% again, and still under `max_gb`. ONTAP moved the FlexVol on its own, so the 50% ceiling Trident wrote at the last resize stays 4.5.  
Both claims are unchanged. `df` still shows the 2Gi filesystem. Autosize made room for the snapshot. It did not give the application a larger disk.

## I. Delete the snapshot, then trim what is left

Deleting the VolumeSnapshot deletes the LUN clone. Blocks that only the clone was holding come back. The 1200Mi file is still in the live filesystem, so it stays allocated. The FlexVol does not shrink. Autosize has no shrink mode, and neither does the autogrow policy.

```bash
$ kubectl delete -n s29-both volumesnapshot mydata-snapshot
volumesnapshot.snapshot.storage.k8s.io "mydata-snapshot" deleted

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
2

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3.42,
  "used_gb": 1.17,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}
```

The LUN count is 2. `used_gb` fell by about the original 850Mi. `size_gb` is still about 3.42.

Delete that last file and trim `mydata` again. This time no clone references the blocks, so the unmap reaches the aggregate. The FlexVol size stays where autosize left it.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- rm -f /data/random

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3.42,
  "used_gb": 1.17,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}

$ bash trim.sh s29-both busybox mydata

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_K7NQWMPXAR",
  "size_gb": 3.42,
  "used_gb": 0.05,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 4.5
}

$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 25m
mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 23m
```

The pool is a FlexVol of about 3.42Gi with almost nothing in it. The claims are still 2Gi and 1Gi. Growing is all either mechanism does.

| Step | mydata | mydata2 | FlexVol size | FlexVol used |
| :--- | :--- | :--- | :--- | :--- |
| Second PVC created | 1Gi | 1Gi | 2 | ~0 |
| 850Mi written on mydata | 2Gi | 1Gi | 3 | ~0.9 |
| 500Mi written on mydata2 | 2Gi | 1Gi | 3 | ~1.4 |
| Snapshot of mydata | 2Gi | 1Gi | 3 | ~1.4 |
| Both files deleted | 2Gi | 1Gi | 3 | ~1.4 |
| Trim mydata2 | 2Gi | 1Gi | 3 | ~0.9 |
| Trim mydata | 2Gi | 1Gi | 3 | ~0.9 |
| 1200Mi written on mydata | 2Gi | 1Gi | ~3.4 | ~2.1 |
| Snapshot deleted | 2Gi | 1Gi | ~3.4 | ~1.2 |
| Last file deleted and trimmed | 2Gi | 1Gi | ~3.4 | ~0 |

## J. Cleanup

`csi-snap-class` is shared with Scenario13. Leave it in place.

```bash
kubectl delete ns s29-both
kubectl delete -f sc-iscsi-eco-both.yaml
kubectl delete -f backend-iscsi-eco-both.yaml
kubectl delete -f autogrow-policy.yaml
```

Or go back to the [scenario introduction](../README.md).
