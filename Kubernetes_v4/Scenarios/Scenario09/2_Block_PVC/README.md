#########################################################################################
# SCENARIO 12: iSCSI Volume resizing
#########################################################################################

**GOAL:**  
Here we will go through a iSCSI PVC Expansion ...

Resizing a PVC is made available through the option *allowVolumeExpansion* set in the StorageClass.

<p align="center"><img src="../Images/scenario09_2.jpg"></p>

If you have not yet read the [Addenda09](../../../Addendum/Addenda09) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario09_pull_images.sh_ you can use in this context to pull images used in this scenario. It uses 2 parameters, your Docker Hub login & password:

```bash
sh ../scenario09_pull_images.sh my_login my_password
```

## A. Create a new storage class with the option allowVolumeExpansion

If you dont have a ONTAP-SAN Backend, please refer to the [scenario05](../../Scenario05) to add one.  

Next, you can create the Storage Class

```bash
$ kubectl create -f sc-csi-ontap-san-resize.yaml
storageclass.storage.k8s.io/sc-san-resize created

$ kubectl get sc
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-san-resize   csi.trident.netapp.io   Delete          Immediate           true                   3h3m
```

## B. Setup the environment

Now let's create a PVC & a Centos POD using this PVC, in their own namespace.

```bash
$ kubectl create namespace resize
namespace/resize created
$ kubectl create -n resize -f pvc.yaml
persistentvolumeclaim/pvc-to-resize-block created

$ kubectl -n resize get pvc,pv
NAME                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
persistentvolumeclaim/pvc-to-resize-block   Bound    pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   5Gi        RWO            sc-san-resize   11s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                        STORAGECLASS    REASON   AGE
persistentvolume/pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   5Gi        RWO            Delete           Bound    resize/pvc-to-resize-block   sc-san-resize            10s

$ kubectl create -n resize -f pod-centos-san.yaml
pod/centosblock created

$ kubectl -n resize get pod --watch
NAME          READY   STATUS              RESTARTS   AGE
centosblock   0/1     ContainerCreating   0          5s
centosblock   1/1     Running             0          15s
```

You can now check that the 5G volume is indeed mounted into the POD.

```bash
$ kubectl -n resize exec centosblock -- df -h /data
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdc        4.8G   20M  4.6G   1% /data
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
  storageClassName: sc-san-resize
  volumeMode: Filesystem
  volumeName: pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8
```

Let's see the result (it takes about 1 minute to take effect).

```bash
$ kubectl -n resize get pvc,pv
NAME                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
persistentvolumeclaim/pvc-to-resize-block   Bound    pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   15Gi       RWO            sc-san-resize   4m3s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                        STORAGECLASS    REASON   AGE
persistentvolume/pvc-0862979c-92ca-49ed-9b1c-15edb8f36cb8   15Gi       RWO            Delete           Bound    resize/pvc-to-resize-block   sc-san-resize            4m2s

$ kubectl -n resize exec centosblock -- df -h /data
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdd         15G   25M   14G   1% /data
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

$ kubectl delete sc sc-san-resize
storageclass.storage.k8s.io "sc-san-resize" deleted
```

## D. What's next

You can now move on to:

- [Scenario10](../../Scenario10): Using Virtual Storage Pools  
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)