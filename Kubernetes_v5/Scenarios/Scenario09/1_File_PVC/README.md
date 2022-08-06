#########################################################################################
# SCENARIO 9.1: NFS Volume resizing
#########################################################################################

**GOAL:**  
Here we will go through a NFS Resizing ...

Resizing a PVC is made available through the option *allowVolumeExpansion* set in the StorageClass.  

We consider that the ONTAP-NAS backend has already been created. ([cf Scenario04](../../Scenario02))

<p align="center"><img src="../Images/scenario09_1.jpg"></p>

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario09_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 optional parameters, your Docker Hub login & password:

```bash
sh ../scenario09_pull_images.sh my_login my_password
```

## A. Check storage classes

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
persistentvolumeclaim/pvc-to-resize-file created

$ kubectl -n resize get pvc,pv
NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/pvc-to-resize-file   Bound    pvc-7eeea3f7-1bea-458b-9824-1dd442222d55   5Gi        RWX            storage-class-nas   2s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS        REASON   AGE
persistentvolume/pvc-7eeea3f7-1bea-458b-9824-1dd442222d55   5Gi        RWX            Delete           Bound    resize/pvc-to-resize-file   storage-class-nas            1s

$ kubectl create -n resize -f pod-busybox-nas.yaml
pod/busyboxfile created

$ kubectl -n resize get pod --watch
NAME          READY   STATUS              RESTARTS   AGE
busyboxfile   0/1     ContainerCreating   0          5s
busyboxfile   1/1     Running             0          15s
```

You can now check that the 5G volume is indeed mounted into the POD.

```bash
$ kubectl -n resize exec busyboxfile -- df -h /data
Filesystem                                                    Size      Used Available Use% Mounted on
192.168.0.132:/nas1_pvc_7eeea3f7_1bea_458b_9824_1dd442222d55  5.0G    256.0K      5.0G   0% /data
```

## C. Resize the PVC & check the result

Resizing a PVC can be done in different ways. We will here edit the definition of the PVC & manually modify it.  
Look for the *storage* parameter in the spec part of the definition & change the value (here for the example, we will use 15GB)

```bash
$ kubectl -n resize edit pvc pvc-to-resize-file
persistentvolumeclaim/pvc-to-resize-file edited

spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 15Gi
  storageClassName: storage-class-nas
  volumeMode: Filesystem
  volumeName: pvc-7eeea3f7-1bea-458b-9824-1dd442222d55
```

Let's see the result.

```bash
$ kubectl -n resize get pvc
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
pvc-to-resize-file   Bound    pvc-7eeea3f7-1bea-458b-9824-1dd442222d55   15Gi       RWX            storage-class-nas   144m

$ kubectl -n resize exec busyboxfile -- df -h /data
Filesystem                                                    Size       Used Available Use% Mounted on
192.168.0.132:/nas1_pvc_7eeea3f7_1bea_458b_9824_1dd442222d55  15.0G    256.0K     15.0G   0% /data
```

As you can see, the resizing was done totally dynamically without any interruption.  
If you have configured Grafana, you can go back to your dashboard, to check what is happening (cf http://192.168.0.63:30267).  

This could also have been achieved by using the _kubectl patch_ command. Try the following one:

```bash
kubectl patch -n resize pvc pvc-to-resize-file -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## C. Cleanup the environment

```bash
$ kubectl delete namespace resize
namespace "resize" deleted
```

## D. What's next

You can now move on to:

- [Scenario9.2](../2_Block_PVC): Resize a iSCSI CSI PVC  
- [Scenario10](../../Scenario10): Using Virtual Storage Pools  
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
