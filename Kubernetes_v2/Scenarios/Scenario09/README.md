#########################################################################################
# SCENARIO 9: NFS Volume resizing
#########################################################################################

**GOAL:**  
Trident supports the resizing of File (NFS) & Block (iSCSI) PVC, depending on the Kubernetes version.  
NFS Resizing was introduced in K8S 1.11, while iSCSI resizing was introduced in K8S 1.16.  
Here we will go through a NFS Resizing ...

Resizing a PVC is made available through the option *allowVolumeExpansion* set in the StorageClass.  

We consider that the ONTAP-NAS backend has already been created. ([cf Scenario04](../Scenario02))

<p align="center"><img src="Images/scenario09.JPG"></p>

## A. Create a new storage class with the option allowVolumeExpansion.

```bash
$ kubectl create -f sc-csi-ontap-nas-resize.yaml
storageclass.storage.k8s.io/sc-nas-resize created
```

## B. Setup the environment

Now let's create a PVC & a Centos POD using this PVC, in their own namespace.

```bash
$ kubectl create namespace resize
namespace/resize created
$ kubectl create -n resize -f pvc.yaml
persistentvolumeclaim/pvc-to-resize created

$ kubectl -n resize get pvc,pv
NAME                                  STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
persistentvolumeclaim/pvc-to-resize   Bound    pvc-7eeea3f7-1bea-458b-9824-1dd442222d55   5Gi        RWX            sc-nas-resize   2s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS    REASON   AGE
persistentvolume/pvc-7eeea3f7-1bea-458b-9824-1dd442222d55   5Gi        RWX            Delete           Bound    resize/pvc-to-resize   sc-nas-resize            1s

$ kubectl create -n resize -f pod-centos-nas.yaml
pod/centos created

$ kubectl -n resize get pod --watch
NAME     READY   STATUS              RESTARTS   AGE
centos   0/1     ContainerCreating   0          5s
centos   1/1     Running             0          15s
```

You can now check that the 5G volume is indeed mounted into the POD.

```bash
$ kubectl -n resize exec centos -- df -h /data
Filesystem                                                    Size  Used Avail Use% Mounted on
192.168.0.135:/nas1_pvc_7eeea3f7_1bea_458b_9824_1dd442222d55  5.0G  256K  5.0G   1% /data
```

## C. Resize the PVC & check the result

Resizing a PVC can be done in different ways. We will here edit the definition of the PVC & manually modify it.  
Look for the *storage* parameter in the spec part of the definition & change the value (here for the example, we will use 15GB)

```bash
$ kubectl -n resize edit pvc pvc-to-resize
persistentvolumeclaim/pvc-to-resize edited

spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 15Gi
  storageClassName: sc-nas-resize
  volumeMode: Filesystem
  volumeName: pvc-7eeea3f7-1bea-458b-9824-1dd442222d55
```

Let's see the result.

```bash
$ kubectl -n resize get pvc
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
pvc-to-resize   Bound    pvc-7eeea3f7-1bea-458b-9824-1dd442222d55   15Gi       RWX            sc-nas-resize   144m

$ kubectl -n resize exec centos -- df -h /data
Filesystem                                                    Size  Used Avail Use% Mounted on
192.168.0.135:/nas1_pvc_7eeea3f7_1bea_458b_9824_1dd442222d55   15G  256K   15G   1% /data
```

As you can see, the resizing was done totally dynamically without any interruption.  
If you have configured Grafana, you can go back to your dashboard, to check what is happening (cf http://192.168.0.141).  

This could also have been achieved by using the _kubectl patch_ command. Try the following one:

```bash
kubectl patch -n resize pvc pvc-to-resize -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## C. Cleanup the environment

```bash
$ kubectl delete namespace resize
namespace "resize" deleted

$ kubectl delete sc sc-nas-resize
storageclass.storage.k8s.io "sc-nas-resize" deleted
```

## D. What's next

You can now move on to:

- [Scenario10](../Scenario10): Using Virtual Storage Pools 
- [Scenario11](../Scenario11): StatefulSets & Storage consumption 
- [Scenario12](../Scenario12): Resize a iSCSI CSI PVC  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)