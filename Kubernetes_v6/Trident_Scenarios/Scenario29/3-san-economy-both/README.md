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
The claim is then already at `maxSize`, so a filesystem that passes 80% again stays at 2Gi. The blocks the snapshot is holding, plus new data written into both filesystems, push the 5Gi FlexVol through 60%. That growth is autosize.

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
The names and the readings through the snapshot are from a run of this chapter. From the trim on, the readings are what the write counts below should produce, on that same volume.

## A. Policy, backend, storage class

Autosize is a backend setting. `storagePrefix: san_eco_both_` gives this demo FlexVols of its own, so the policy cannot rewrite the pools from [Scenario05](../../Scenario05) or from the previous folder.  
`maximumSize` has to be a percentage on `ontap-san-economy`. `50%` means the FlexVol may grow to 1.5 times the size it has when Trident writes the setting.  
The storage class pins the pool to `aggr1`, so both LUNs land in one FlexVol.  
`spaceAllocation: "true"` in the backend `defaults` asks Trident to enable space allocation, so ONTAP advertises UNMAP on those LUNs. It is a backend setting, not a storage class parameter. `formatOptions: -E nodiscard` is also a backend setting. It is passed to `mkfs.ext4` and skips the discard of the whole LUN while the filesystem is created. It has no effect later, when a file is deleted. The storage class in the previous chapter mounts with `discard`, and that mount option is what unmaps blocks at delete time. This storage class has no `mountOptions`, so a delete and a trim stay two readings.  
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
backend-iscsi-eco-both   BackendForiSCSIEcoBoth  6c52b319-aaef-4782-9c28-6280e6716d8d   Bound   Success
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
pod/busybox-5ff9685889-jzpf2   1/1     Running   0          25s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 25s
```

```bash
$ PV=$(kubectl get pvc -n s29-both mydata -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV -o jsonpath='{.config.ontapAutosizeMode} {.config.ontapAutosizeGrowThresholdPercent} {.config.ontapAutosizeMaximumSize}'; echo
grow 60 50%

$ VOLNAME=$(kubectl get -n trident tvol $PV -o=jsonpath='{.config.internalID}' | cut -d/ -f5)
$ echo $VOLNAME
trident_lun_pool_san_eco_both_MUWKJRWYGR

$ VOLUUID=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid')
$ s29_ontap() {
  curl -s -ku admin:Netapp1! -H "accept: application/json" \
    "https://cluster1.demo.netapp.com/api/storage/volumes/${VOLUUID}?fields=name,space.size,space.used,autosize" \
    | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
}
$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
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
pod/busybox-5ff9685889-jzpf2    1/1     Running   0          5m
pod/busybox2-6f66fc5975-v4zq2   1/1     Running   0          20s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                       VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata    Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 5m1s
persistentvolumeclaim/mydata2   Bound    pvc-aa9d1617-e11b-4a11-9cc4-f9ec4d872d67   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 20s
```

Both LUNs should name the same FlexVol:

```bash
$ PV2=$(kubectl get pvc -n s29-both mydata2 -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV2 -o=jsonpath='{.config.internalID}' | cut -d/ -f5
trident_lun_pool_san_eco_both_MUWKJRWYGR

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
2

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 2,
  "used_gb": 0.06,
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
/dev/mapper/3600a0980774f6a34712b572d41767234
                        973.4M     24.0K    906.2M   0% /data

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767235
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
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 2,
  "used_gb": 0.78,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 3
}

$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                       VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 8m32s
mydata2   Bound    pvc-aa9d1617-e11b-4a11-9cc4-f9ec4d872d67   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 3m51s
```

A LUN resize is slow enough that you can often catch the request Trident raises for it:

```bash
$ kubectl get tagri -n trident
NAME                                             VOLUME                                     AUTOGROW POLICY   OBSERVED USED%   OBSERVED CAPACITY   FINAL SIZE   PHASE        AGE
tagri-pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   s29-both          93.799355        1020702720          2147483648   InProgress   18s
```

About a minute after the write, `mydata` is 2Gi. `mydata2` is still 1Gi. The policy is per PVC: the neighbor's filesystem is empty, so that claim stays.

```bash
$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 6m
mydata2   Bound    pvc-aa9d1617-e11b-4a11-9cc4-f9ec4d872d67   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 4m

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767234
                          1.9G    850.0M   1022.7M  45% /data

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 3,
  "used_gb": 0.9,
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
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                       VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 12m
mydata2   Bound    pvc-aa9d1617-e11b-4a11-9cc4-f9ec4d872d67   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 7m44s

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
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
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              2Gi           csi-snap-class   snapcontent-d2d60057-ee02-43c0-9a54-a0d66ef9bd97   8s             8s

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
3

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5,
  "used_gb": 1.39,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}
```

The LUN count went from 2 to 3. The third LUN is the clone, and it is 2Gi because it copies the size of `mydata` at the moment of the snapshot. Trident sizes the FlexVol to the sum of its LUNs, so the pool grows from 3Gi to 5Gi even though `used_gb` does not move. `max_gb` follows the new size. Both claims are still 2Gi and 1Gi. The cost of this snapshot shows up at the next delete.

## F. Delete

Remove the file on both pods. `df` recovers. The LUNs still own the blocks: nothing has sent UNMAP, and the clone of `mydata` needs its blocks anyway.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- rm -f /data/random
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- rm -f /data/random

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767234
                          1.9G     24.0K      1.8G   0% /data

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767235
                        973.4M     24.0K    906.2M   0% /data

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5,
  "used_gb": 1.39,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}
```

Both filesystems are empty. `used_gb` is still 1.39, because the clone still holds the blocks of `mydata` and nothing has sent UNMAP for `mydata2`. The claims are still 2Gi and 1Gi. Autogrow watches a filesystem that just emptied, so it stays quiet. Autosize does not shrink.

## G. Trim

`trim.sh` runs `fstrim -v /data` from the BusyBox image. That image already contains `fstrim`. The volume is not mounted with `discard`, so the unmap has to be asked for. The FITRIM ioctl needs `CAP_SYS_ADMIN`, which the application pods do not have, so the script starts a short-lived pod with that capability only. The pod mounts the same claim and is pinned to the node that already has it, which is what a `ReadWriteOnce` volume allows.

Trim `mydata2` first. Nothing snapshots that LUN, so ONTAP can return those blocks.

```bash
$ bash trim.sh s29-both busybox2 mydata2
trimming mydata2 on rhel1
pod/fstrim created
pod/fstrim condition met
/data: 1020678144 bytes trimmed

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5,
  "used_gb": 0.9,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}
```

`used_gb` fell by about the 500Mi. `size_gb` is still 5. The PVC capacities are still 2Gi and 1Gi.

Trim `mydata` next. `fstrim` runs, and the clone still references the 850Mi. UNMAP does not free a block a snapshot needs.

```bash
$ bash trim.sh s29-both busybox mydata
trimming mydata on rhel1
pod/fstrim created
pod/fstrim condition met
/data: 2077048832 bytes trimmed

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5,
  "used_gb": 0.9,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}
```

`used_gb` is still about 0.9. The guest discarded the free space of `mydata`. The LUN clone kept the blocks, inside the FlexVol `mydata2` also lives on. One PVC's snapshot is sitting in the pool both claims share. 0.9Gi is 18% of the 5Gi FlexVol, so autosize stays quiet. 60% of this pool is 3Gi.

## H. Writes that grow the FlexVol

The clone already made the pool 5Gi, so one more file on `mydata` cannot cross 60% by itself. The filesystem there is about 1.9Gi, and the clone is still holding the old 850Mi. Filling both filesystems, while leaving both claims where they are, is what gets used space past 3Gi.

1700Mi is about 87% of the 2Gi filesystem. That is past the 80% autogrow threshold, and `mydata` is already at `maxSize`, so the claim stays 2Gi. The new blocks are not the blocks the clone holds, so used space climbs by about that 1700Mi, to about 2.6Gi. That is still about half of the 5Gi FlexVol.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=1700'

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5,
  "used_gb": 2.57,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}

$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 20m
mydata2   Bound    pvc-aa9d1617-e11b-4a11-9cc4-f9ec4d872d67   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 18m

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767234
                          1.9G      1.7G    172.7M  91% /data
```

`size_gb` is still 5. Both claims are unchanged.

700Mi is about 77% of the usable space on `mydata2`. The same accounting called the 850Mi write 93.8% full, so 80% of this 1Gi filesystem is about 725Mi, and 700Mi stays under it. The claim stays 1Gi. Added to the blocks the clone is holding and to the 1700Mi just written, used space is about 3.2Gi. That is past 60% of 5Gi. The writes fit in the 5Gi, so they can finish, and ONTAP grows the FlexVol afterwards. Give it a few seconds.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=700'

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5.3,
  "used_gb": 3.15,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}

$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767235
                        973.4M    700.0M    206.2M  77% /data
```

`size_gb` is about 5.3, just large enough that `used_gb` sits under 60% again, and still under `max_gb`. ONTAP moved the FlexVol on its own, so the 50% ceiling Trident wrote at the last resize stays 7.5.  
Both claims are unchanged. `df` still shows the 2Gi filesystem on `mydata` and the 1Gi filesystem on `mydata2`. Autosize made room for the snapshot and for the new data. It did not give either application a larger disk.

## I. Delete the snapshot, then trim what is left

Deleting the VolumeSnapshot deletes the LUN clone. Blocks that only the clone was holding come back. The 1700Mi file and the 700Mi file are still in the live filesystems, so they stay allocated. The FlexVol does not shrink. Autosize has no shrink mode, and neither does the autogrow policy. Deleting the clone does not shrink it either.

```bash
$ kubectl delete -n s29-both volumesnapshot mydata-snapshot
volumesnapshot.snapshot.storage.k8s.io "mydata-snapshot" deleted

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
2

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5.48,
  "used_gb": 3.25,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}
```

The LUN count is 2. `used_gb` fell by about the original 850Mi. `size_gb` is still about 5.48.

Delete both new files and trim each claim. This time no clone references the blocks, so the unmap reaches the aggregate. The FlexVol size stays where autosize left it.

```bash
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox -o name) -- rm -f /data/random
$ kubectl exec -n s29-both $(kubectl get pod -n s29-both -l app=busybox2 -o name) -- rm -f /data/random

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5.48,
  "used_gb": 2.42,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}

$ bash trim.sh s29-both busybox mydata
$ bash trim.sh s29-both busybox2 mydata2

$ s29_ontap
{
  "name": "trident_lun_pool_san_eco_both_MUWKJRWYGR",
  "size_gb": 5.48,
  "used_gb": 0.08,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 7.5
}

$ kubectl get pvc -n s29-both
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                        VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-3f599143-bd42-4aa3-a83f-0a7d7a058f94   2Gi        RWO            storage-class-iscsi-economy-both   <unset>                 25m
mydata2   Bound    pvc-aa9d1617-e11b-4a11-9cc4-f9ec4d872d67   1Gi        RWO            storage-class-iscsi-economy-both   <unset>                 23m
```

The pool is a FlexVol of about 5.41Gi with almost nothing in it. The claims are still 2Gi and 1Gi. Growing is all either mechanism does.

| Step | mydata | mydata2 | FlexVol size | FlexVol used |
| :--- | :--- | :--- | :--- | :--- |
| Second PVC created | 1Gi | 1Gi | 2 | ~0 |
| 850Mi written on mydata | 2Gi | 1Gi | 3 | 0.78 |
| 500Mi written on mydata2 | 2Gi | 1Gi | 3 | 1.39 |
| Snapshot of mydata | 2Gi | 1Gi | 5 | 1.39 |
| Both files deleted | 2Gi | 1Gi | 5 | 1.39 |
| Trim mydata2 | 2Gi | 1Gi | 5 | ~0.9 |
| Trim mydata | 2Gi | 1Gi | 5 | ~0.9 |
| 1700Mi written on mydata | 2Gi | 1Gi | 5 | ~2.6 |
| 700Mi written on mydata2 | 2Gi | 1Gi | ~5.4 | ~3.2 |
| Snapshot deleted | 2Gi | 1Gi | ~5.4 | ~2.3 |
| Both files deleted and trimmed | 2Gi | 1Gi | ~5.4 | ~0 |

## J. Cleanup

`csi-snap-class` is shared with Scenario13. Leave it in place.

```bash
kubectl delete ns s29-both
kubectl delete -f sc-iscsi-eco-both.yaml
kubectl delete -f backend-iscsi-eco-both.yaml
kubectl delete -f autogrow-policy.yaml
```

Or go back to the [scenario introduction](../README.md).
