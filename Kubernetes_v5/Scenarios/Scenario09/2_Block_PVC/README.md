#########################################################################################
# SCENARIO 12: iSCSI Volume resizing
#########################################################################################

**GOAL:**  
Here we will go through a iSCSI PVC Expansion ...

Resizing a PVC is made available through the option *allowVolumeExpansion* set in the StorageClass.

<p align="center"><img src="../Images/scenario09_2.jpg"></p>

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario09_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 **optional** parameters, your Docker Hub login & password:

```bash
sh ../scenario09_pull_images.sh my_login my_password
```

## A. Check storage classes

If you dont have a ONTAP-SAN Backend, nor a SAN storage class, please refer to the [scenario05](../../Scenario05) to add one.  
Next, Let's check the storage classes we have at hand.

```bash
$ kubectl get sc
NAME                          PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storage-class-nas (default)   csi.trident.netapp.io   Delete          Immediate           true                   94m
storage-class-nas-economy     csi.trident.netapp.io   Delete          Immediate           true                   94m
storage-class-san             csi.trident.netapp.io   Delete          Immediate           true                   94m
storage-class-san-economy     csi.trident.netapp.io   Delete          Immediate           true                   94m
```

As you can see, all storage classes created previously have the expansion capability.

## B. Setup the environment

Now let's create a PVC & a Centos POD using this PVC, in their own namespace.

```bash
$ kubectl create namespace resize
namespace/resize created
$ kubectl create -n resize -f pvc.yaml
persistentvolumeclaim/pvc-to-resize-block created

$ kubectl -n resize get pvc,pv
NAME                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/pvc-to-resize-block   Bound    pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   5Gi        RWO            storage-class-san   11s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                        STORAGECLASS        REASON   AGE
persistentvolume/pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   5Gi        RWO            Delete           Bound    resize/pvc-to-resize-block   storage-class-san            10s

$ kubectl create -n resize -f pod-busybox-san.yaml
pod/busyboxblock created

$ kubectl -n resize get pod --watch
NAME           READY   STATUS              RESTARTS   AGE
busyboxblock   0/1     ContainerCreating   0          5s
busyboxblock   1/1     Running             0          15s
```

You can now check that the 5G volume is indeed mounted into the POD.

```bash
$ kubectl -n resize exec busyboxblock -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/sdc                  4.8G     20.0M      4.5G   0% /data
```

## C. Resize the PVC & check the result

Resizing a PVC can be done in different ways. We will here edit the definition of the PVC & manually modify it.  
Look for the *storage* parameter in the spec part of the definition & change the value (here for the example, we will use 15GB)

```bash
$ kubectl -n resize edit pvc pvc-to-resize-block
persistentvolumeclaim/pvc-to-resize-block edited

spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 15Gi
  storageClassName: storage-class-san
  volumeMode: Filesystem
  volumeName: pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8
```

Let's see the result (it takes a few seconds to take effect).

```bash
$ kubectl -n resize get pvc,pv
NAME                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/pvc-to-resize-block   Bound    pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   15Gi       RWO            storage-class-san   4m3s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                        STORAGECLASS        REASON   AGE
persistentvolume/pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   15Gi       RWO            Delete           Bound    resize/pvc-to-resize-block   storage-class-san            4m2s

$ kubectl -n resize exec busyboxblock -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
/dev/sdc                 14.6G     24.9M     13.9G   0% /data
```

As you can see, the resizing was done totally dynamically without any interruption.  
The POD rescanned its devices to discover the new size of the volume.  

If you have configured Grafana, you can go back to your dashboard, to check what is happening (cf http://192.168.0.63:30267).  

This could also have been achieved by using the _kubectl patch_ command. Try the following one:

```bash
kubectl patch -n resize pvc pvc-to-resize-block -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## C. Cleanup the environment

```bash
$ kubectl delete namespace resize
namespace "resize" deleted
```

## D. What's next

You can now move on to:

- [Scenario10](../../Scenario10): Using Virtual Storage Pools  
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)