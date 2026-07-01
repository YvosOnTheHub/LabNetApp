#########################################################################################
# SCENARIO 7-2: Import NFS Qtrees with ONTAP-NAS-ECONOMY
#########################################################################################

**GOAL:**  
You will learn on this chapter how to import multiple qtrees with the ONTAP-NAS-ECONOMY driver.  
This feature was introduced in Trident 26.06.

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario07_pull_images.sh* to pull images utilized in this scenario if needed:  
```bash
sh ../scenario07_pull_images.sh
```

## A. Requirements.

Make sure you have installed Trident 26.06 in order to test this scenario.  
If not done yet, please refer to [Scenario01](../../Trident_Scenarios/Scenario01) to perform this update.

## B. Scenario preparation.

In order to import things, we first need to create them...  
Let's create a FlexVol (*scenario7_2*), as well as a 2 Qtrees (*qtree1* & *qtree2*) in the ONTAP cli:  
```bash
cluster1::> volume create -vserver nassvm scenario7_2 -size 10G -aggregate aggr1 -junction-path /scenario7_2
cluster1::> volume qtree create -vserver nassvm -volume scenario7_2 -qtree qtree1
cluster1::> volume qtree create -vserver nassvm -volume scenario7_2 -qtree qtree2
cluster1::> volume quota policy rule create -vserver nassvm -policy-name default -volume scenario7_2 -type tree -disk-limit 1GB -target qtree1
cluster1::> volume quota policy rule create -vserver nassvm -policy-name default -volume scenario7_2 -type tree -disk-limit 2GB -target qtree2
cluster1::> volume quota on -vserver nassvm -volume scenario7_2
```
Let's also create a specific namespace for this scenario:  
```bash
kubectl create ns scenario7-2
```
<!--
volume create -vserver nassvm scenario7_2 -size 10G -aggregate aggr1 -junction-path /scenario7_2
volume qtree create -vserver nassvm -volume scenario7_2 -qtree qtree1
volume qtree create -vserver nassvm -volume scenario7_2 -qtree qtree2
volume quota policy rule create -vserver nassvm -policy-name default -volume scenario7_2 -type tree -disk-limit 1GB -target qtree1
volume quota policy rule create -vserver nassvm -policy-name default -volume scenario7_2 -type tree -disk-limit 2GB -target qtree2
volume quota on -vserver nassvm -volume scenario7_2
volume quota policy rule show -vserver nassvm -policy-name default -volume scenario7_2
-->

## C. Import Qtrees !  

This could be achieved either with _tridentctl_ or _kubectl_. We will cover here the second method.  

Remember that you need the Trident backend UUID in order to import qtree:  
```bash
$ kuectl get tbc backend-nfs-qtrees -n trident
NAME                 BACKEND NAME          BACKEND UUID                           PHASE   STATUS
backend-nfs-qtrees   BackendForNFSQtrees   244e5c5e-10ee-479b-bf01-8765b9840259   Bound   Success
```
Let's import a Qtree:  
```bash
$ cat << EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data1
  namespace: scenario7-2
  annotations:
    trident.netapp.io/importOriginalName: "scenario7_2/qtree1"
    trident.netapp.io/importBackendUUID: "244e5c5e-10ee-479b-bf01-8765b9840259"
    trident.netapp.io/notManaged: "false"
    trident.netapp.io/importNoRename: "false"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: storage-class-nas-economy
EOF
persistentvolumeclaim/data1 created
```
If all went well, you should see:  
```bash
$ kubecetl get -n scenario7-2 pvc
NAME    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE
data1   Bound    pvc-8b0de79a-e77d-4876-9ea2-85949614294b   1Gi        RWX            storage-class-nas-economy   <unset>                 5m9s
```
Let's deploy a pod to mount this volume:  
```bash
$ kubectl create -f busybox1.yaml
pod/busybox created

$ kubectl get -n scenario7-2 po,pvc
NAME           READY   STATUS    RESTARTS   AGE
pod/busybox1   1/1     Running   0          16s

NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/data1   Bound    pvc-8b0de79a-e77d-4876-9ea2-85949614294b   1Gi        RWX            storage-class-nas-economy   <unset>                 4m43s
```

Time to check up what we have.  
First, let's see inside the pod:  
```bash
$ kubectl exec -n scenario7-2 pod/busybox1 -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
192.168.0.131:/scenario7_2/nas_eco_pvc_8b0de79a_e77d_4876_9ea2_85949614294b
                          1.0G         0      1.0G   0% /data
```
As expected, the Qtree's name changed to follow Trident's default naming convention.  

Notice that the FlexVol seems to be unchanged in the mount path.  
Actually, the **junction path** (internal mount in ONTAP) of the parent volume did not change, however the FlexVol itself changed:  
```bash
cluster1::> vol show -vserver nassvm -volume trident_qtree_pool_nas_eco_FQMHSFMXCH -fields junction-path
vserver volume                                junction-path
------- ------------------------------------- -------------
nassvm  trident_qtree_pool_nas_eco_FQMHSFMXCH /scenario7_2
```
With that change at the storage layer, the next Qtree import manifest will look a bit different, and must reflect the new FlexVol name. For the fun, let's also use the _noRename_  parameter:  
```bash
$ cat << EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data2
  namespace: scenario7-2
  annotations:
    trident.netapp.io/importOriginalName: "trident_qtree_pool_nas_eco_FQMHSFMXCH/qtree2"
    trident.netapp.io/importBackendUUID: "244e5c5e-10ee-479b-bf01-8765b9840259"
    trident.netapp.io/notManaged: "false"
    trident.netapp.io/importNoRename: "true"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: storage-class-nas-economy
EOF
persistentvolumeclaim/data2 created
```
The PVC is immediately avaialble: 
```bash
$ kubectl get -n scenario7-2 pvc
NAME    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                VOLUMEATTRIBUTESCLASS   AGE
data1   Bound    pvc-8b0de79a-e77d-4876-9ea2-85949614294b   1Gi        RWX            storage-class-nas-economy   <unset>                 27m
data2   Bound    pvc-ba593d3c-c38e-4666-9561-afa7344c5c64   1Gi        RWX            storage-class-nas-economy   <unset>                 9s
```
Let's deploy a new pod alongside this new PVC & check the content:  
```bash
$ kubectl create -f busybox2.yaml
pod/busybox2 created

$ kubectl exec -n scenario7-2 busybox2 -- df /data
Filesystem           1K-blocks      Used Available Use% Mounted on
192.168.0.131:/scenario7_2/qtree2
                       2097152         0   2097152   0% /data
```
As you can notice, the qtree name stayed unchanged.  
You can also validate this behavior by looking at the Qtrees in ONTAP:  
```bash
cluster1::> qtree show -vserver nassvm -volume trident_qtree_pool_nas_eco_FQMHSFMXCH
Vserver    Volume        Qtree        Style        Oplocks   Status
---------- ------------- ------------ ------------ --------- --------
nassvm     trident_qtree_pool_nas_eco_FQMHSFMXCH
                         ""           unix         enable    normal
nassvm     trident_qtree_pool_nas_eco_FQMHSFMXCH
                         nas_eco_pvc_52475066_a2cb_48a2_99ab_798498ae6544
                                      unix         enable    normal
nassvm     trident_qtree_pool_nas_eco_FQMHSFMXCH
                         qtree2       unix         enable    normal
3 entries were displayed.
```
There you go, one qtree renamed (_qtree1_ to *nas_eco_pvc_52475066_a2cb_48a2_99ab_798498ae6544*)& one qtree unchanged (_qtree2_)

If you were to import a qtree, which pool does not follow Trident's nameing convention, you would see the following message in the PVC:  
```bash
$ kubectl get events -n scenario7-2 --field-selector involvedObject.kind=PersistentVolumeClaim
LAST SEEN   TYPE      REASON                  OBJECT                        MESSAGE
60s         Normal    ExternalProvisioning    persistentvolumeclaim/data1   Waiting for a volume to be created either by the external provisioner 'csi.trident.netapp.io' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
103s        Normal    Provisioning            persistentvolumeclaim/data1   External provisioner is provisioning volume for claim "scenario7-2/data1"
103s        Warning   ProvisioningFailed      persistentvolumeclaim/data1   rpc error: code = Unknown desc = failed to import volume scenario7_2/qtree1 on backend 244e5c5e-10ee-479b-bf01-8765b9840259: driver import volume failed: could not import volume/qtree, volume is named incorrectly: scenario7_2, expected pattern: trident_qtree_pool_nas_eco_*, volume scenario7_2/qtree1 not found on backend BackendForNFSQtrees; volume scenario7_2/qtree1 not found
```

Great, you know now how to import Qtrees, and the impact on the ONTAP volume name.  
Let's clean up the namespace:
```bash
kubectl delete ns scenario7-2
```

<!-- API CALLS TO CREATE VOL & QTREE
$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "aggregates": [{"name": "aggr1"}],
  "name": "scenario7_2",
  "size": "10g",
  "style": "flexvol",
  "svm": {"name": "nassvm"}
}' "https://cluster1.demo.netapp.com/api/storage/volumes"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "name": "qtree1",
  "volume": {"name": "scenario7_2"},
  "svm": {"name": "nassvm"}
}' "https://cluster1.demo.netapp.com/api/storage/qtrees"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "name": "qtree2",
  "volume": {"name": "scenario7_2"},
  "svm": {"name": "nassvm"}
}' "https://cluster1.demo.netapp.com/api/storage/qtrees"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "type": "tree",
  "qtree": {"name": "qtree1"},
  "volume": {"name": "scenario7_2"},
  "svm": {"name": "nassvm"},
  "space": {"hard_limit": 1099511627776}
}' "https://cluster1.demo.netapp.com/api/storage/quota/rules"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "type": "tree",
  "qtree": {"name": "qtree2"},
  "volume": {"name": "scenario7_2"},
  "svm": {"name": "nassvm"},
  "space": {"hard_limit": 1099511627776}
}' "https://cluster1.demo.netapp.com/api/storage/quota/rules"
-->
