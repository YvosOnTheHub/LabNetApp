#########################################################################################
# SCENARIO 29: Automatic volume expansion  
#########################################################################################

Trident 26.02 introduced the possibility to automatically grow Persistent Volumes. This is comparable to the ONTAP autogrow feature, however as expansion is managed directly from Kubernetes, this is much better for configuration consistency.  

In order to use that feature, you need:  
- the _allowVolumeExpansion_ parameter set in the storage class. 
- to create a TridentAutogrowPolicy that can be assigned to a storage class or a PVC. 

Note that is not currently supported with SMB.  

If you want to know all the details, the following link contains a lot of information with regards to that feature: https://docs.netapp.com/us-en/trident/trident-use/automatic-volume-expansion.html#requirements

A TridentAutogrowPolicy (_TAG_) is a new Trident CRD, which contains 3 configurable parameters:  
- usedThreshold (%): percentage of used capacity that trigger the volume expansion.  
- growthAmount (% or size): growth amount (optional, defaults to 10%).  
- maxSize: maximum size a volume can reach (optional). 

Let's create one for our scenario:  
```bash
$ cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentAutogrowPolicy
metadata:
  name: demo-autogrow
spec:
  usedThreshold: "80%"
  growthAmount: "2Gi"
  maxSize: "15Gi"
EOF
tridentautogrowpolicy.trident.netapp.io/demo-autogrow created

$ kubectl get tap
NAME            USED THRESHOLD   GROWTH AMOUNT   STATE
demo-autogrow   80%              2Gi             Success

$ kubectl get tap -o wide
NAME            USED THRESHOLD   GROWTH AMOUNT   MAX SIZE   STATE     MESSAGE
demo-autogrow   80%              2Gi             15Gi       Success   Autogrow policy validated and ready to use
```

Assigning that policy to a storage class can be done with the annotation **trident.netapp.io/autogrowPolicy**.  
Here is an example of a NFS Storage Class which allows that feature:  
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-nfs-tap
  annotations:
    trident.netapp.io/autogrowPolicy: "demo-autogrow"
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  nasType: "nfs"
allowVolumeExpansion: true
```
Updating an existing storage class can be done simply with the _kubectl annotate_ command. Here is an example:  
```bash
kubectl annotate storageclass storage-class-nfs trident.netapp.io/autogrowPolicy="demo-autogrow" --overwrite
```

Let's create a Busybox app with a NFS PVC configured with Autogrow, directly with an annotation embedded in the PVC definition.  

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario29_pull_images.sh* to pull images utilized in this scenario if needed:  
```bash
sh scenario29_pull_images.sh
```

You can also find in this folder the application definition that you will use:  
```bash
$ kubectl create -f busybox.yaml
namespace/busybox-tap created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n busybox-tap po,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5ff9685889-8rx9w   1/1     Running   0          75s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-dc93409f-e343-45bc-b929-3bfd6f633434   10Gi       RWX            storage-class-nfs   <unset>                 75s
```
You can verify which policy is assigned to the PVC by running:  
```bash
$ kubectl get pvc mydata -n busybox-tap -o jsonpath='{.metadata.annotations.trident\.netapp\.io/autogrowPolicy}'; echo
demo-autogrow
```
You can also check how many volumes are assigned to such policies:  
```bash
$ tridentctl -n trident get agp
+---------------+----------------+---------------+----------+---------+
|     NAME      | USED THRESHOLD | GROWTH AMOUNT | MAX SIZE | VOLUMES |
+---------------+----------------+---------------+----------+---------+
| demo-autogrow | 80%            | 2Gi           | 15Gi     |       1 |
+---------------+----------------+---------------+----------+---------+
```

Let's write 9Gi of data in the PVC, which should trigger the volume growth:  
```bash
$ kubectl exec -n busybox-tap $(kubectl get pod -n busybox-tap -o name) -- sh -c 'dd if=/dev/urandom of=/data/random bs=1M count=9000'
9000+0 records in
9000+0 records out
9437184000 bytes (8.8GB) copied, 33.129494 seconds, 271.7MB/s
```
Let's immediately check the used space in the volume with the ONTAP API:  
```bash
$ VOLNAME=$(kubectl get -n trident tvol $(kubectl get pvc -n busybox-tap mydata -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.config.internalName}')
$ VOLUUID=$(curl -X GET -sku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME" -H "accept: application/json" | jq -r .records[0].uuid)
$ curl -X GET -sku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID" -H "accept: application/json" | jq -r '.space.used/1024/1024/1024*100|round/100'
8.83
```
=> 8.83GB is above the threshold, you can then expect a volume size change shortly.  

Trident regularly check the size of volumes (every minute).  
If a threshold is passed, Trident will create a CR called **TridentAutoGrowRequestInternal** (_TAGRI_) that will request the PVC resize.  
This object is short lived with NFS as resize is almost immediate, you may not catch it ...

However, you can retrieve information from the Trident logs and follow every steps involved in increasing the size of the volume:  
```bash
time="2026-03-04T07:40:37Z" level=info msg="Resolved effective Autogrow policy from PVC annotation" agPolicyName=demo-autogrow logLayer=core requestID=d767edbf-3e80-4f9a-b570-a51fe2020cec requestSource=CSI source=PVC volumeName=pvc-dc93409f-e343-45bc-b929-3bfd6f633434 workflow="volume=create"
time="2026-03-04T07:40:39Z" level=info msg="Publishing volume to node." logLayer=core node=rhel1 requestID=f4a5b330-6aae-4292-9231-84a8bd6c4f0f requestSource=CSI volume=pvc-dc93409f-e343-45bc-b929-3bfd6f633434 workflow="controller_server=publish"
time="2026-03-04T07:42:56Z" level=info msg="Processing TAGRI." crdControllerEvent=add eventType=add key=trident/tagri-pvc-dc93409f-e343-45bc-b929-3bfd6f633434 logLayer=crd_frontend logSource=trident-crd-controller requestID=63dee4e6-a6a5-44b1-8ed8-e4e2d6ae60eb requestSource=CRD workflow="cr=reconcile"
time="2026-03-04T07:42:56Z" level=info msg="Successfully patched PVC size." crdControllerEvent=add logLayer=crd_frontend logSource=trident-crd-controller newSize=12.00Gi newSizeBytes=12884901888 pvc=mydata requestID=63dee4e6-a6a5-44b1-8ed8-e4e2d6ae60eb requestSource=CRD workflow="cr=reconcile"
time="2026-03-04T07:42:57Z" level=info msg="Orchestrator resized the volume on the storage backend." logLayer=core requestID=39a0c306-47eb-44d8-86d8-b6bda9017702 requestSource=CSI volume=pvc-dc93409f-e343-45bc-b929-3bfd6f633434 volume_size=12884901888 workflow="volume=resize"
time="2026-03-04T07:42:57Z" level=info msg="TAGRI completed successfully." crdControllerEvent=add finalSize=12.00Gi logLayer=crd_frontend logSource=trident-crd-controller requestID=63dee4e6-a6a5-44b1-8ed8-e4e2d6ae60eb requestSource=CRD tagri=tagri-pvc-dc93409f-e343-45bc-b929-3bfd6f633434 workflow="cr=reconcile"
time="2026-03-04T07:42:57Z" level=info msg="TAGRI deleted successfully." crdControllerEvent=add logLayer=crd_frontend logSource=trident-crd-controller requestID=63dee4e6-a6a5-44b1-8ed8-e4e2d6ae60eb requestSource=CRD tagri=tagri-pvc-dc93409f-e343-45bc-b929-3bfd6f633434 workflow="cr=reconcile"
```
The PVC is now resized:  
```bash
$ kubectl get -n busybox-tap pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-dc93409f-e343-45bc-b929-3bfd6f633434   12Gi       RWX            storage-class-nfs   <unset>                 11m
```
Let's write more data. With 2 extra GB, we will be cross the threshold again !  
```bash
$ kubectl exec -n busybox-tap $(kubectl get pod -n busybox-tap -o name) -- sh -c 'dd if=/dev/urandom of=/data/random2 bs=1M count=2000'
2000+0 records in
2000+0 records out
2097152000 bytes (2.0GB) copied, 12.541450 seconds, 159.5MB/s
```
Time to quickly check again the used space in the volume:  
```bash
$ VOLNAME=$(kubectl get -n trident tvol $(kubectl get pvc -n busybox-tap mydata -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.config.internalName}')
$ VOLUUID=$(curl -X GET -sku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME" -H "accept: application/json" | jq -r .records[0].uuid)
$ curl -X GET -sku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID" -H "accept: application/json" | jq -r '.space.used/1024/1024/1024*100|round/100'
10.79
```
Once again, 10,79GB is above the 80% used space threshold.  
And just a few seconds later, the volume is resized with 2 extra Gi:  
```bash
$ kubectl get -n busybox-tap pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-dc93409f-e343-45bc-b929-3bfd6f633434   14Gi       RWX            storage-class-nfs   <unset>                 13m
```
We are getting closer to the maximum possible size for the PVC!  
Let's add another 2,5GB that should take us to close to 14GB of used space:  
```bash
$ kubectl exec -n busybox-tap $(kubectl get pod -n busybox-tap -o name) -- sh -c 'dd if=/dev/urandom of=/data/random3 bs=1M count=2500'
2500+0 records in
2500+0 records out
2621440000 bytes (2.4GB) copied, 13.563170 seconds, 184.3MB/s
```
Last size verification:  
```bash
$ VOLNAME=$(kubectl get -n trident tvol $(kubectl get pvc -n busybox-tap mydata -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.config.internalName}')
$ VOLUUID=$(curl -X GET -sku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes?name=$VOLNAME" -H "accept: application/json" | jq -r .records[0].uuid)
$ curl -X GET -sku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes/$VOLUUID" -H "accept: application/json" | jq -r '.space.used/1024/1024/1024*100|round/100'
13.24
```
This will trigger another volume expansion, but instead of adding 2GB, it will take us to the ceiling of 15Gi:  
```bash
$ kubectl get -n busybox-tap pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-dc93409f-e343-45bc-b929-3bfd6f633434   15Gi       RWX            storage-class-nfs   <unset>                 17m
```

And voilà, pretty straight forward, isn't it ?  

You can now delete the namespace if you like:  
```bash
kubectl delete ns busybox-tap
```

If you were to try this demo with a block protocol instead of NFS, you would have plenty of time to check the _TAGRI_, as resizing a LUN takes some time to complete. Here is an example of a TAGRI with an iSCSI LUN:  
```bash
$ kubectl get tagri -n trident
NAME                                             VOLUME                                     AUTOGROW POLICY   OBSERVED USED%   OBSERVED CAPACITY   FINAL SIZE    PHASE        AGE
tagri-pvc-e9453d73-59ba-4d27-8b4f-15ab1ec4fc0f   pvc-e9453d73-59ba-4d27-8b4f-15ab1ec4fc0f   demo-autogrow     95.22559         10464022528         12884901888   InProgress   14s
```