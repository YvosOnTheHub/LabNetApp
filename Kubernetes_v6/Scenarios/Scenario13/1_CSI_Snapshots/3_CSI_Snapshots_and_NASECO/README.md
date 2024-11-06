#########################################################################################
# SCENARIO13: CSI Snapshots & ONTAP-NAS-ECONOMY
#########################################################################################

Trident 24.06.1 introduced the possibility to create CSI Snapshots for Qtree based workloads.  
We will see in this scenario what you can or cannot do with such snapshot.  

In order for this lab to succeed, you must have first gone through the following:  
- [Scenario01](../../../Scenario01) Upgrade Trident to 24.10.0
- [Scenario02](../../../Scenario02/1_Local_User/) Create the ONTAP-NAS-ECONOMY Trident backend & storage class  

You can find a shell script in this directory _scenario13_busybox_pull_images.sh_ to pull images utilized in this scenario if needed:  
```bash
sh scenario13_busybox_pull_images.sh
```

## A. Prepare the environment

We will create an app in its own namespace _sc13busybox_.  
```bash
$ kubectl create -f busybox.yaml
namespace/sc13busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc13busybox pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-8698c48d88-26gg4   1/1     Running   0          3m17s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-8d0a4104-c2e5-46c5-a1ee-14fb8232a4af   1Gi        RWX            storage-class-nas-economy   <unset>                 3m17s
```
Also, let's write some content in this PVC:  
```bash
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- sh -c 'echo "NAS ECO clone test!" > /data/test.txt'
$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -o name) -- more /data/test.txt
NAS ECO clone test!
```

## B. Create a CSI snapshot

Let's create a snapshot & see the result on the storage backend:  
```bash
$ kubectl create -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get -n sc13busybox vs
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              1Gi           csi-snap-class   snapcontent-e046cf37-c150-4b0b-812d-bad728678016   2s             3s

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+---------+
|                     NAME                      |                  VOLUME                  | MANAGED |
+-----------------------------------------------+------------------------------------------+---------+
| snapshot-e046cf37-c150-4b0b-812d-bad728678016 | pvc-8d0a4104-c2e5-46c5-a1ee-14fb8232a4af | true    |
+-----------------------------------------------+------------------------------------------+---------+
```
The snapshot creation succeeded & it is _READYTOUSE_.  
Now, let's find out the name of the ONTAP FlexVol that contains our qtree (ie PVC):
```bash
$ kubectl get -n trident tvol $(kubectl get -n sc13busybox pvc mydata -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.config.internalID}' | awk -F '/' '{print $5}'
trident_qtree_pool_nas_eco_BKJTNKBRCE
```
Finally, let's validate through ONTAP API that our snapshot is indeed at the FlexVol level:
```bash
FLEXVOLGET=$(curl -s -X GET -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes?name=trident_qtree_pool_nas_eco_BKJTNKBRCE" -H "accept: application/json")
FLEXVOLUUID=$(echo $FLEXVOLGET | jq -r .records[0].uuid)
curl -s -X GET -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes/$FLEXVOLUUID/snapshots" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "01cfcdda-5b91-433c-8209-b1043ccdb785",
      "name": "snapshot-e046cf37-c150-4b0b-812d-bad728678016"
    }
  ],
  "num_records ": 1
}[
```
As expected, we just validated that the snapshot sits at the FlexVol level.

## C. Now what? Can you create a clone from this snapshot?  

**Answer: well, yes & no...**  

First try, with a standard PVC manifest.  
You will see that PVC will remain in a _Pending_ state:  
```bash
$ kubectl get -f pvcfromsnap.yaml 
persistentvolumeclaim/mydata-from-snap created

$ kubectl get -n sc13busybox pvc
NAME               STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE
mydata             Bound     pvc-8d0a4104-c2e5-46c5-a1ee-14fb8232a4af   1Gi        RWX            storage-class-nas-economy   <unset>                 9m7s
mydata-from-snap   Pending                                                                        storage-class-nas-economy   <unset>                 17s

$ kubectl describe -n sc13busybox pvc mydata-from-snap
...
Events:
  Type     Reason                Age                From                                                                                            Message
  ----     ------                ----               ----                                                                                            -------
  Normal   Provisioning          12s (x3 over 37s)  csi.trident.netapp.io_trident-controller-85574d7d77-phrrx_0e3fea11-42ee-47ab-8e20-45c833de287f  External provisioner is provisioning volume for claim "sc13busybox/mydata-from-snap"
  Warning  ProvisioningFailed    12s (x3 over 36s)  csi.trident.netapp.io_trident-controller-85574d7d77-phrrx_0e3fea11-42ee-47ab-8e20-45c833de287f  failed to provision volume with StorageClass "storage-class-nas-economy": rpc error: code = Unknown desc = failed to create cloned volume pvc-ffe07920-431b-4643-9c72-2a15111ff8b3 on backend BackendForNFSQtrees: cloning is not supported by backend type ontap-nas-economy
  Normal   ExternalProvisioning  5s (x4 over 37s)   persistentvolume-controller                                                                     Waiting for a volume to be created either by the external provisioner 'csi.trident.netapp.io' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
```

Now, let's try a different way with a specific annotation _trident.netapp.io/readOnlyClone: "true"_.  
The clone will work, but you won't be able to write in it. This is essentially done to enable data protection, as backup processes will only read the content of the volume:  
```bash
$ kubectl get -n sc13busybox pvc
NAME                  STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE
mydata                Bound     pvc-8d0a4104-c2e5-46c5-a1ee-14fb8232a4af   1Gi        RWX            storage-class-nas-economy   <unset>                 16m
mydata-from-snap      Pending                                                                        storage-class-nas-economy   <unset>                 4m6s
mydata-from-snap-ro   Bound     pvc-e2bfd628-9d7c-4717-9379-af114ed8cb38   1Gi        RWX            storage-class-nas-economy   <unset>                 11s
```
Time to verify if we can read the content of the volume & if we can also write in it.  
```bash
$ kubectl get -n sc13busybox pod
NAME                           READY   STATUS    RESTARTS   AGE
busybox-8698c48d88-g2nmt       1/1     Running   0          22m

$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -l app=busybox-clone -o name) -- more /data/test.txt
NAS ECO clone test!

$ kubectl exec -n sc13busybox $(kubectl get pod -n sc13busybox -l app=busybox-clone -o name) -- sh -c 'echo "Write in clone" > /data/test2.txt'
sh: can't create /data/test2.txt: Read-only file system
command terminated with exit code 1
```
& voilà 

## Optional Cleanup

```bash
$ kubectl delete ns sc13busybox
namespace "sc13busybox" deleted
```