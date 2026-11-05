#########################################################################################
# SCENARIO 29: ONTAP volume autosize
#########################################################################################

Trident 26.10 can turn on ONTAP volume autosize for the FlexVol that backs a SAN LUN.  
When used space crosses a threshold, ONTAP grows that FlexVol, up to a maximum. The PVC is left alone, and so is the LUN. The extra room is for snapshots and for the overhead around the LUN.  

The details are in the Trident documentation: https://docs.netapp.com/us-en/trident/trident-use/ontap-autosize.html  

This chapter runs the same BusyBox workload four times:  

- [A.](#a-ontap-san-without-autosize) `ontap-san` without autosize  
- [B.](#b-ontap-san-with-autosize) `ontap-san` with autosize  
- [C.](#c-ontap-san-economy-without-autosize) `ontap-san-economy` without autosize  
- [D.](#d-ontap-san-economy-with-autosize) `ontap-san-economy` with autosize  

The two "without" cases reuse the backends and storage classes created in [Scenario05](../../Scenario05): `BackendForiSCSI` / `storage-class-iscsi`, and `BackendForiSCSIEco` / `storage-class-iscsi-economy`. Those backends have no `ontapAutosize` block, so Trident does not touch the autosize settings ONTAP stored on the FlexVol.  

The two "with" cases need their own backends. Autosize is a backend setting, and an `ontap-san-economy` FlexVol can be updated by whichever backend touched it last. A separate backend, with its own `storagePrefix`, keeps this demo off the FlexVols already used by Scenario05.  

Every application uses `registry.demo.netapp.com/busybox:1.35.0`.  
If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
The pull script for this image sits in the parent directory:  
```bash
sh ../scenario29_pull_images.sh
```

Confirm the Scenario05 objects are still there before going on. Both backends should be `Bound` / `Success`:  
```bash
kubectl get -n trident tbc backend-iscsi backend-iscsi-eco
kubectl get sc storage-class-iscsi storage-class-iscsi-economy
```

Each section writes 800Mi of data that will not compress, then compares three things: the PVC capacity, `df` inside the pod, and the FlexVol size reported by ONTAP. On `ontap-san`, that FlexVol size moves only when autosize is on.  

The threshold used below is 60% rather than the default 85%. On `ontap-san`, Trident sizes the FlexVol at the LUN size plus about 10% for LUN metadata, so a 1Gi PVC comes back as a FlexVol of about 1.1Gi. 800Mi is enough to cross 60% of that, and it still fits in the filesystem. `ontap-san-economy` does not add that 10%. Its FlexVol is sized from the LUNs it holds, and Trident grows it when a new LUN is added. That growth is the new PVC, not the data, and it happens whether or not autosize is enabled. The economy sections create a second BusyBox so you can see it.  

## A. ontap-san without autosize

`storage-class-iscsi` selects `BackendForiSCSI`.  
```bash
$ kubectl create -f busybox-san.yaml
namespace/s29-san created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n s29-san pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-8rx9w   1/1     Running   0          40s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   1Gi        RWO            storage-class-iscsi   <unset>                 40s
```

Trident recorded no autosize policy on this volume. The next command prints a blank line:  
```bash
$ PV=$(kubectl get pvc -n s29-san mydata -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV -o jsonpath='{.config.ontapAutosizeMode} {.config.ontapAutosizeGrowThresholdPercent} {.config.ontapAutosizeMaximumSize}'; echo
```

With `ontap-san`, the Trident volume name is the FlexVol name. Read the size and the autosize mode from ONTAP:  
```bash
$ VOLNAME=$(kubectl get -n trident tvol $PV -o=jsonpath='{.config.internalName}')
$ VOLUUID=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid')
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_pvc_e5f85851_f07e_43d5_ac38_f032133cd311",
  "size_gb": 1.1,
  "used_gb": 0.03,
  "mode": "off",
  "grow_threshold": 85,
  "max_gb": 1.32
}

```
`mode` is `off`. `size_gb` is about 1.1, the 1Gi LUN plus the metadata buffer. Keep that size in mind.  

The filesystem the pod can see is the LUN, close to 1Gi:  
```bash
$ kubectl exec -n s29-san $(kubectl get pod -n s29-san -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767174
                        973.4M     24.0K    906.2M   0% /data
```

Write 800Mi. `/dev/urandom` matters here: a stream of zeroes would be swallowed by compression and the FlexVol used space would barely move.  
```bash
$ kubectl exec -n s29-san $(kubectl get pod -n s29-san -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=800'
```

Read the FlexVol again with the same `curl` command.  
`size_gb` is the value you wrote down. `used_gb` has climbed, and `mode` is still `off`.  
The PVC is still 1Gi:  
```bash
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_pvc_e5f85851_f07e_43d5_ac38_f032133cd311",
  "size_gb": 1.1,
  "used_gb": 0.82,
  "mode": "off",
  "grow_threshold": 85,
  "max_gb": 1.32
}

$ kubectl get -n s29-san pvc mydata
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-e5f85851-f07e-43d5-ac38-f032133cd311   1Gi        RWO            storage-class-iscsi   <unset>                 3m2s

$ kubectl exec -n s29-san $(kubectl get pod -n s29-san -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767174
                        973.4M    800.0M    106.2M  88% /data
```
`df /data` shows the filesystem filling up. Nothing grew it, and nothing grew the FlexVol underneath.  

You can delete this namespace before the next section:  
```bash
kubectl delete ns s29-san
```

## B. ontap-san with autosize

The backend in this folder is the Scenario05 iSCSI backend plus an `ontapAutosize` block. `maximumSize: "50%"` means the FlexVol may grow to 1.5 times the size it has at creation. An absolute size (`"2Gi"`, for example) is also accepted on `ontap-san`. It is rejected on `ontap-san-economy`, which is why both demos use a percentage.  
```bash
$ kubectl create -f backend-iscsi-autosize.yaml -f sc-iscsi-autosize.yaml
tridentbackendconfig.trident.netapp.io/backend-iscsi-autosize created
storageclass.storage.k8s.io/storage-class-iscsi-autosize created

$ kubectl get -n trident tbc backend-iscsi-autosize
NAME                     BACKEND NAME              BACKEND UUID                           PHASE   STATUS
backend-iscsi-autosize   BackendForiSCSIAutosize   c7cea2ba-79ec-44e7-a600-31f95fc8af44   Bound   Success
```
`PHASE` should be `Bound` and `STATUS` should be `Success` before you create the PVC.

`storage-class-iscsi-autosize` is pinned to that backend with `storagePools`, so this PVC cannot land on `BackendForiSCSI`.  
```bash
$ kubectl create -f busybox-san-autosize.yaml
namespace/s29-san-as created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n s29-san-as pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-lpgxn   1/1     Running   0          16s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-32b20b0e-07c5-4cbf-b004-48ee4a52b30c   1Gi        RWO            storage-class-iscsi-autosize   <unset>                 16s
```

The policy is now stored on the Trident volume:  
```bash
$ PV=$(kubectl get pvc -n s29-san-as mydata -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV -o jsonpath='{.config.ontapAutosizeMode} {.config.ontapAutosizeGrowThresholdPercent} {.config.ontapAutosizeMaximumSize}'; echo
grow 60 50%
```

And ONTAP received it. Reuse the `curl` from the previous section, with this volume name:  
```bash
$ VOLNAME=$(kubectl get -n trident tvol $PV -o=jsonpath='{.config.internalName}')
$ VOLUUID=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid') 
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_pvc_32b20b0e_07c5_4cbf_b004_48ee4a52b30c",
  "size_gb": 1.1,
  "used_gb": 0.03,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 1.65
}
```
`mode` is `grow`, `grow_threshold` is `60`, and `max_gb` is about one and a half times `size_gb`.  

Same write:  
```bash
$ kubectl exec -n s29-san-as $(kubectl get pod -n s29-san-as -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=800'
```

ONTAP grows the FlexVol on its own. Give it a few seconds and run the `curl` again.  
`size_gb` is larger than the value you just recorded, and it stays under `max_gb`. `used_gb` is still the data you wrote, so the used percentage drops because the denominator grew.  
```bash
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_pvc_32b20b0e_07c5_4cbf_b004_48ee4a52b30c",
  "size_gb": 1.38,
  "used_gb": 0.82,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 1.65
}
```

The claim did not follow:  
```bash
$ kubectl get -n s29-san-as pvc mydata
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                   VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-32b20b0e-07c5-4cbf-b004-48ee4a52b30c   1Gi        RWO            storage-class-iscsi-autosize   <unset>                 5m31s

$ kubectl exec -n s29-san-as $(kubectl get pod -n s29-san-as -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767175
                        973.4M    800.0M    106.2M  88% /data
```
Capacity is 1Gi. `df` still shows the original filesystem. Autosize protected the FlexVol. It did not give the application a larger disk. That is the job of a Trident Autogrow Policy, in the previous folder.  

```bash
kubectl delete ns s29-san-as
```

## C. ontap-san-economy without autosize

You will create a new storge class `storage-class-iscsi-economy-oneaggr` that selects the existing backend `BackendForiSCSIEco`. That storage class can only use one aggregate, which helps in making sure the 2 LUNs of this exercise end up in the same pool.  
Several LUNs share one FlexVol. On the Trident volume, `internalName` is the LUN (`san_eco_pvc_...`). The FlexVol name is inside `internalID`, in a path such as `/svm/sansvm/flexvol/trident_lun_pool_san_eco_OICIQENZQI/lun/san_eco_pvc_...`.  
```bash
$ kubectl create -f sc-iscsi-eco-oneaggr.yaml
storageclass.storage.k8s.io/storage-class-iscsi-economy-oneaggr created

$ kubectl create -f busybox-eco.yaml
namespace/s29-eco created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n s29-eco pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-dlf9s   1/1     Running   0          11s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-e75af29c-8108-4976-9848-e656e1ec958f   1Gi        RWO            storage-class-iscsi-economy-oneaggr   <unset>                 12s
```

The autosize fields are empty again:  
```bash
$ PV=$(kubectl get pvc -n s29-eco mydata -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV -o jsonpath='{.config.ontapAutosizeMode} {.config.ontapAutosizeGrowThresholdPercent} {.config.ontapAutosizeMaximumSize}'; echo
```

The FlexVol name is the 5th field of `internalID`. Read the same ONTAP fields from there:  
```bash
$ VOLNAME=$(kubectl get -n trident tvol $PV -o=jsonpath='{.config.internalID}' | cut -d/ -f5)
$ VOLUUID=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid')
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_lun_pool_san_eco_UYNBWCKZID",
  "size_gb": 1,
  "used_gb": 0.03,
  "mode": "off",
  "grow_threshold": 85,
  "max_gb": 1.2
}
```
The name starts with `trident_lun_pool_san_eco_`. `mode` is `off`.  

If this lab has already created economy LUNs, this LUN may have joined that pool. The size is then the sum of every LUN in it, and 800Mi will look small next to that. You can count them with:  
```bash
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME&svm.name=sansvm&fields=name" | jq '.num_records'
1
```
Either way, write the data and read the FlexVol again:  
```bash
$ kubectl exec -n s29-eco $(kubectl get pod -n s29-eco -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=800'

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_lun_pool_san_eco_UYNBWCKZID",
  "size_gb": 1,
  "used_gb": 0.82,
  "mode": "off",
  "grow_threshold": 85,
  "max_gb": 1.2
}
```
`size_gb` does not move. `mode` stays `off`. The PVC stays 1Gi. The 800Mi changed `used_gb` only.  

A second PVC is a different event. Trident places another 1Gi LUN in the same FlexVol and resizes that FlexVol to the sum of the LUNs. No data is written to the new LUN.  
```bash
$ kubectl create -f busybox-eco2.yaml
persistentvolumeclaim/mydata2 created
deployment.apps/busybox2 created

$ kubectl get -n s29-eco pod,pvc
kubectl get -n s29-eco pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-dlf9s   1/1     Running   0          3m33s
pod/busybox2-8679459f5-b7jwj   1/1     Running   0          9s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata    Bound    pvc-e75af29c-8108-4976-9848-e656e1ec958f   1Gi        RWO            storage-class-iscsi-economy-oneaggr   <unset>                 3m34s
persistentvolumeclaim/mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-oneaggr   <unset>                 9s
```

Both LUNs should name the same FlexVol, and the LUN count goes to 2:  
```bash
$ PV2=$(kubectl get pvc -n s29-eco mydata2 -o=jsonpath='{.spec.volumeName}')
$ VOLNAME2=$(kubectl get -n trident tvol $PV2 -o=jsonpath='{.config.internalID}' | cut -d/ -f5)
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/luns?location.volume.name=$VOLNAME2&svm.name=sansvm&fields=name" | jq '.num_records'
2
```

Read the FlexVol again. `size_gb` is about 2, one gigabyte per LUN. `used_gb` is still the 800Mi from the first pod, because `mydata2` is empty. `mode` is still `off`.  
```bash
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_lun_pool_san_eco_UYNBWCKZID",
  "size_gb": 2,
  "used_gb": 0.85,
  "mode": "off",
  "grow_threshold": 85,
  "max_gb": 2.4
}

$ kubectl get -n s29-eco pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                          VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-e75af29c-8108-4976-9848-e656e1ec958f   1Gi        RWO            storage-class-iscsi-economy-oneaggr   <unset>                 8m52s
mydata2   Bound    pvc-78f5bd68-9902-443e-ac89-84a365f60225   1Gi        RWO            storage-class-iscsi-economy-oneaggr   <unset>                 5m27s
```
Both claims stay at 1Gi. The FlexVol grew to make room for the second LUN, with autosize disabled.  

There is no 10% metadata buffer on this driver, and a snapshot here is a LUN clone stored in this same FlexVol. With autosize left off, those clones have only whatever free space the pool already has.  

```bash
kubectl delete ns s29-eco
```

## D. ontap-san-economy with autosize

This backend sets the same 60% / 50% policy. `storagePrefix: san_eco_as_` gives it FlexVols of its own, so applying the policy cannot rewrite the Scenario05 pool. On this driver `maximumSize` has to be a percentage.  
Note that the storage class explicitly limits the choice to one aggregate, so that you don't end up with one pool per aggregate.  
```bash
$ kubectl create -f backend-iscsi-eco-autosize.yaml -f sc-iscsi-eco-autosize.yaml
tridentbackendconfig.trident.netapp.io/backend-iscsi-eco-autosize created
storageclass.storage.k8s.io/storage-class-iscsi-economy-autosize created

$ kubectl get -n trident tbc backend-iscsi-eco-autosize
NAME                         BACKEND NAME                 BACKEND UUID                           PHASE   STATUS
backend-iscsi-eco-autosize   BackendForiSCSIEcoAutosize   37744e2d-9ce4-4c31-9505-aa89eefc712f   Bound   Success
```
Wait until that backend is `Bound` / `Success`. The storage class pins the PVC to it, so a backend that is still creating would leave the claim `Pending`.

```bash
$ kubectl create -f busybox-eco-autosize.yaml
namespace/s29-eco-as created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n s29-eco-as pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-kzqsx   1/1     Running   0          107s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                           VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-23f3153b-beef-477f-9ad1-4e6bf3d7129b   1Gi        RWO            storage-class-iscsi-economy-autosize   <unset>                 107s
```
Read the same ONTAP fields from there:
```bash
$ PV=$(kubectl get pvc -n s29-eco-as mydata -o=jsonpath='{.spec.volumeName}')
$ kubectl get -n trident tvol $PV -o jsonpath='{.config.ontapAutosizeMode} {.config.ontapAutosizeGrowThresholdPercent} {.config.ontapAutosizeMaximumSize}'; echo
grow 60 50%

$ VOLNAME=$(kubectl get -n trident tvol $PV -o=jsonpath='{.config.internalID}' | cut -d/ -f5)
$ echo $VOLNAME
trident_lun_pool_san_eco_as_QEQYEJNGMP

$ VOLUUID=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid')
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_lun_pool_san_eco_as_QEQYEJNGMP",
  "size_gb": 1,
  "used_gb": 0.03,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 1.5
}
```
The FlexVol name starts with `trident_lun_pool_san_eco_as_`. It holds this LUN and nothing carried over from Scenario05. `mode` is `grow`, and `max_gb` is about 1.5 times `size_gb`.  

Write some data:  
```bash
$ kubectl exec -n s29-eco-as $(kubectl get pod -n s29-eco-as -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=800'
```

A few seconds later the same `curl` shows a larger `size_gb`, still at or under `max_gb`.  
```bash
$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_lun_pool_san_eco_as_QEQYEJNGMP",
  "size_gb": 1.38,
  "used_gb": 0.82,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 1.5
}

$ kubectl get -n s29-eco-as pvc mydata
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                           VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-23f3153b-beef-477f-9ad1-4e6bf3d7129b   1Gi        RWO            storage-class-iscsi-economy-autosize   <unset>                 7m42s

$ kubectl exec -n s29-eco-as $(kubectl get pod -n s29-eco-as -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/mapper/3600a0980774f6a34712b572d41767231
                        973.4M    800.0M    106.2M  88% /data
```
The PVC and the filesystem are unchanged. That growth came from used space crossing 60%.  

The second PVC grows the same FlexVol for another reason. Trident adds a 1Gi LUN and resizes the pool to fit it. The new LUN is empty, so this step is not a used-space event.  
```bash
$ kubectl create -f busybox-eco-autosize2.yaml
persistentvolumeclaim/mydata2 created
deployment.apps/busybox2 created

$ kubectl get -n s29-eco-as pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-ttv7m   1/1     Running   0          3m13s
pod/busybox2-8679459f5-qqkcm   1/1     Running   0          7s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                           VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata    Bound    pvc-23f3153b-beef-477f-9ad1-4e6bf3d7129b   1Gi        RWO            storage-class-iscsi-economy-autosize   <unset>                 3m13s
persistentvolumeclaim/mydata2   Bound    pvc-179bb108-af37-4ca2-9a98-87b4d25ef179   1Gi        RWO            storage-class-iscsi-economy-autosize   <unset>                 7s
```

Confirm the second LUN landed in the same FlexVol, then read the size again:  
```bash
$ PV2=$(kubectl get pvc -n s29-eco-as mydata2 -o=jsonpath='{.spec.volumeName}')

$ VOLNAME2=$(kubectl get -n trident tvol $PV2 -o=jsonpath='{.config.internalID}' | cut -d/ -f5)
$ echo $VOLNAME2
trident_lun_pool_san_eco_as_QEQYEJNGMP

$ VOLUUID2=$(curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME&fields=uuid" | jq -r '.records[0].uuid')

$ curl -s -ku admin:Netapp1! -H "accept: application/json" "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID2?fields=name,space.size,space.used,autosize" | jq '{name, size_gb: (.space.size/1024/1024/1024*100|round/100), used_gb: (.space.used/1024/1024/1024*100|round/100), mode: .autosize.mode, grow_threshold: .autosize.grow_threshold, max_gb: (.autosize.maximum/1024/1024/1024*100|round/100)}'
{
  "name": "trident_lun_pool_san_eco_as_QEQYEJNGMP",
  "size_gb": 2,
  "used_gb": 0.85,
  "mode": "grow",
  "grow_threshold": 60,
  "max_gb": 3
}

$ kubectl get -n s29-eco-as pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                           VOLUMEATTRIBUTESCLASS   AGE
mydata    Bound    pvc-23f3153b-beef-477f-9ad1-4e6bf3d7129b   1Gi        RWO            storage-class-iscsi-economy-autosize   <unset>                 4m39s
mydata2   Bound    pvc-179bb108-af37-4ca2-9a98-87b4d25ef179   1Gi        RWO            storage-class-iscsi-economy-autosize   <unset>                 93s
```
`size_gb` grows by about the size of the new LUN. `used_gb` stays at the 800Mi already written. Both PVCs still report 1Gi. Trident also recalculates the 50% ceiling against the new FlexVol size, so `max_gb` moves up with it.  

```bash
kubectl delete ns s29-eco-as
```

## E. Cleanup

The Scenario05 backends were only read. The two backends from this folder can go when you are done:  
```bash
kubectl delete -f sc-iscsi-autosize.yaml -f sc-iscsi-eco-autosize.yaml
kubectl delete -f backend-iscsi-autosize.yaml -f backend-iscsi-eco-autosize.yaml
```

The [next folder](../3-san-economy-both) runs this autosize policy together with a Trident Autogrow Policy, on one economy pool, through a snapshot, a delete and a trim.  

Or go back to the [scenario introduction](../README.md).  
