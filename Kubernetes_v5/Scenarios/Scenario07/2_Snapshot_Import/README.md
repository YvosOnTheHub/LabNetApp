#########################################################################################
# SCENARIO 7-2: Import a snapshot  
#########################################################################################

This feature was introduced in Trident 23.07.  

In order to use it, the volume that owns the snapshot must already be represented in Kubernetes as a PVC.  
It can be either :
- a PVC created by an end user, with a snapshot created on the storage backend (manually or scheduled)  
- a PVC imported in Kubernetes, which contains the snapshot we want to import

We are going to import a snapshot belonging to a volume imported with Trident (covered in the first chapter of this scenario).  

CSI Snapshots are Kubernetes objects created & managed by the end-user in his own namespace. They will eventually trigger the creation of a ONTAP Snapshot on the storage backend. Until now, you could not create out of the box a CSI snapshot based on an existing ONTAP Snapshot, hence the creation of this feature to help you achieve this.  

Persistent Volumes rely on 2 layers:
- user space: Persistent Volume Claim (aka PVC)
- cluster wide resource: Persistent Volume (aka PV)
If managed dynamically, PVC are also linked to a Storage Class.  

Snapshots follow the same logic:
- user space: Volume Snapshot (aka VS)
- cluster wide resource: Volume Snapshot Content (aka VSC)
If managed dynamically, VS are also linked to a Snapshot Class.  

Importing a snapshot will use pre-provisioned VSC, created by the cluster admin.  
This object contains a reference to:
- the PV name where the snapshot exists
- the snapshot name (in this example _snap-to-import_ which was created in the first chapter)

## A. Import a snapshot

The _volumesnapshotcontent.sh_ script will retrieve for you the PV name of the volume _blog-content-import_ and create the VSC object:
```bash
$ sh volumesnapshotcontent.sh
volumesnapshotcontent.snapshot.storage.k8s.io/vsc-import created

$ kubectl get vsc
NAME         READYTOUSE   RESTORESIZE   DELETIONPOLICY   DRIVER                  VOLUMESNAPSHOTCLASS   VOLUMESNAPSHOT   VOLUMESNAPSHOTNAMESPACE   AGE
vsc-import   true         774144        Delete           csi.trident.netapp.io                         volumesnap       ghost                     39m
```
Notice the field _ReadyToUse=True_ which shows it worked!  

We can now proceed with the creation of the VS in the user namespace:
```bash
$ kubectl create -f volumesnapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/volumesnap created

$ kubectl -n ghost get vs
NAME         READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT   CREATIONTIME   AGE
volumesnap   true                     vsc-import              756Ki                         vsc-import        57m            48m
```
Here again, the _ReadToUse_ field shows a succesful result.

## B. Create a full application from this snapshot

Here we are, let's create a volume from the snapshot, followed by a new Ghost instance:
```bash
$ kubectl create -f ghost-pvc.yaml 
persistentvolumeclaim/blog-content-from-snap created

$ kubectl create -f ghost-app.yaml
deployment.apps/blogsnapimport created
service/blogsnapimport created

$ kubectl -n ghost get pod,pvc,svc -l app=blogsnapimport
NAME                                  READY   STATUS    RESTARTS   AGE
pod/blogsnapimport-66b4c955f8-qvv7k   1/1     Running   0          5m15s

NAME                                           STATUS   VOLUME                                     CAPACITY    ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/blog-content-from-snap   Bound    pvc-f7af70d7-56e8-42a5-ac65-7d3a5e70040b   5518824Ki   RWX            storage-class-nas   14m

NAME                     TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/blogsnapimport   NodePort   10.99.106.183   <none>        80:30083/TCP   26s
```

You can finally access this instance of Ghost created from an imported snapshot on the _30083_ port.

A few things to notice:
- in this example, I configured the VSC with a _DeletionPolicy=Delete_. You can also try with the value _Retain_, which will not delete neither the snapshot nor the volume  
- it was not necessary to create a snapshot class for this example, as this feature is not based on a dynamic method, but rather a preprovisioned snapshot.  

## C. Cleanup

The _ghost_ namespace is not required anymore in this scenario. You can now delete it.  
```bash
$ kubectl delete ns ghost
namespace "ghost" deleted
```

## D. What's next

You can now move on to:

- [Scenario07_3](../3_SAN_import): Importing a SAN volume  
- [Scenario08](../../Scenario08): Consumption control  
- [Scenario10](../../Scenario10): Using Virtual Storage Pools 
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
