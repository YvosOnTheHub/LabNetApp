#########################################################################################
# SCENARIO 27: Creating Virtual Machines: boot volume clone
#########################################################################################

In this last chapter, we will see how to create a new Virtual Machine after an existing one.  
Multiple scenarios can be tested:  
- [Method1](#method1) cloning within the same namespace (strategy: copy)  
- [Method2](#method2) cloning to a different namespace (strategy: copy)  
- [Method3](#method3) cloning within the same namespace (strategy: snapshot)  
- [Method4](#method4) cloning to a different namespace (strategy: snapshot)  
 
**TL;DR START**  
Using snapshots is **MUCH** faster !!
**TL;DR STOP**

For the purpose of creating a disk from an existing one, a new CRD is introduced here, the **storageProfile**. It maps a Kubernetes StorageClass to CDI import/clone/snapshot behaviors used when creating DataVolumes. It is not a KubeVirt core API, but CDI uses it for VM disk import/clone workflows.  

When creating a DataVolume, CDI looks for the storageProfile matching the requested storageClassName and follows its status fields (ex: cloneStrategy, snapshotClass ...) to decide whether it can do instant CSI cloning or must copy the data, which volumeMode/accessModes to request, and which snapshot class to use.  

There is one storageProfile per storageClass, created with the same name.  
```bash
$ kubectl get storageprofile
NAME                          AGE
storage-class-iscsi           20h
storage-class-iscsi-economy   20h
storage-class-nas-economy     20h
storage-class-nfs             20h
storage-class-nvme            20h
storage-class-smb             20h
```
As we have used the _storage-class-iscsi_ one for this scenario, let's check its content:  
```bash
$ kubectl get storageprofile storage-class-iscsi -o yaml
apiVersion: cdi.kubevirt.io/v1beta1
kind: StorageProfile
metadata:
  creationTimestamp: "2025-11-10T15:05:18Z"
  generation: 1
  labels:
    app: containerized-data-importer
    app.kubernetes.io/component: storage
    app.kubernetes.io/managed-by: cdi-controller
    cdi.kubevirt.io: ""
  name: storage-class-iscsi
...
status:
  claimPropertySets:
  - accessModes:
    - ReadWriteMany
    volumeMode: Block
  cloneStrategy: copy
  dataImportCronSourceFormat: pvc
  provisioner: csi.trident.netapp.io
  storageClass: storage-class-iscsi
```
Notice that the **cloneStrategy** is set to **copy**. This is because I don't have a **volumeSnapshotClass** available just yet. If you have one, delete it in order continue with this chapter.  

For this chapter, let's suppose you have already gone through the [third method](../3_Method3/), and the content is still present. Cloning a disk requires the source Virtual Machine to be offline.  
Let's stop the VM using _virtctl_:  
```bash
$ virtctl stop -n sc26-alpine-c alpine-vm
VM alpine-vm was scheduled to stop
```

## A. Cloning within the same namespace (strategy: copy) 
<a name="method1"></a>

Let's see how to create a clone of the existing Virtual Machine using a DataVolume:  
```bash
$ cat << EOF | kubectl apply  -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: alpine-boot-clone
  namespace: sc26-alpine-c
  labels:
    method: clone1
spec:
  pvc:
    accessModes:
      - ReadWriteMany
    resources:
      requests:
        storage: 1Gi
    volumeMode: Block
    storageClassName: storage-class-iscsi
  contentType: kubevirt
  source:
    pvc:
      name: alpine-boot
      namespace: sc26-alpine-c
EOF
datavolume.cdi.kubevirt.io/alpine-boot-clone created
```
This triggers the creation of multiple objects:  
- a **tmp-pvc**
- the target **alpine-boot-clone** pvc
- **2 temporary pods**, one that manages the _clone_ process and one that _copies_ the content of the disk:  

```bash
$ kubectl get -n sc26-alpine-c all,pvc
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                                          READY   STATUS          RESTARTS   AGE
pod/b21e6444-ddcf-4aa6-a893-71653fbbb2a2-source-pod           1/1     Running         0          1s
pod/cdi-upload-tmp-pvc-8901a9d1-d945-4b1c-91c5-586a92696cea   1/1     Running         0          19s

NAME                                                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/cdi-upload-tmp-pvc-8901a9d1-d945-4b1c-91c5-586a92696cea   ClusterIP   10.98.247.45   <none>        443/TCP   19s

NAME                                           PHASE             PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot         Succeeded         N/A                   59m
datavolume.cdi.kubevirt.io/alpine-boot-clone   CloneInProgress   N/A                   19s

NAME                                   AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-vm   56m   Stopped   False

NAME                                                                 STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot                                    Bound     pvc-dedf8d1e-ae3e-4f84-bfe4-ca5a3d9ab446   1Gi        RWX            storage-class-iscsi   <unset>                 59m
persistentvolumeclaim/alpine-boot-clone                              Pending                                                                        storage-class-iscsi   <unset>                 19s
persistentvolumeclaim/tmp-pvc-8901a9d1-d945-4b1c-91c5-586a92696cea   Bound     pvc-b21e6444-ddcf-4aa6-a893-71653fbbb2a2   1Gi        RWX            storage-class-iscsi   <unset>                 19s
```
Here are the logs you can read from both temporary pods:  
```bash
$ kubectl logs -n sc26-alpine-c pod/cdi-upload-tmp-pvc-8901a9d1-d945-4b1c-91c5-586a92696cea -f
I1111 09:53:28.521523       1 uploadserver.go:81] Running server on 0.0.0.0:8443
I1111 09:53:38.855537       1 uploadserver.go:410] Content type header is "blockdevice-clone"
I1111 09:53:38.860307       1 file.go:230] copyWithSparseCheck to /dev/cdi-block-volume
I1111 09:53:56.713029       1 file.go:195] Read 1073741824 bytes, wrote 120193024 bytes to /dev/cdi-block-volume
I1111 09:53:56.713636       1 uploadserver.go:436] Wrote data to /dev/cdi-block-volume
I1111 09:53:56.714463       1 uploadserver.go:215] Shutting down http server after successful upload
I1111 09:53:56.718794       1 uploadserver.go:115] UploadServer successfully exited

$ kubectl logs -n sc26-alpine-c pod/b21e6444-ddcf-4aa6-a893-71653fbbb2a2-source-pod -f
VOLUME_MODE=block
MOUNT_POINT=/dev/cdi-block-volume
UPLOAD_BYTES=1073741824
I1111 09:53:38.389872       3 clone-source.go:223] content-type is "blockdevice-clone"
I1111 09:53:38.389962       3 clone-source.go:224] mount is "/dev/cdi-block-volume"
I1111 09:53:38.389969       3 clone-source.go:225] upload-bytes is 1073741824
I1111 09:53:38.389981       3 clone-source.go:242] Starting cloner target
I1111 09:53:38.826712       3 clone-source.go:258] Set header to blockdevice-clone
I1111 09:53:39.391368       3 prometheus.go:78] 5.07
...
I1111 09:53:56.407041       3 prometheus.go:78] 98.44
I1111 09:53:56.698781       3 clone-source.go:127] Wrote 1073741824 bytes
I1111 09:53:56.716160       3 clone-source.go:276] Response body:
I1111 09:53:56.716392       3 clone-source.go:278] clone complete
```
Once the copy is completed, temporary resources are deleted:  
```bash
$ kubectl get -n sc26-alpine-c all,pvc -l method=clone1
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                           PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot-clone   Succeeded   100.0%                94s

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-clone   Bound    pvc-b21e6444-ddcf-4aa6-a893-71653fbbb2a2   1Gi        RWX            storage-class-iscsi   <unset>                 95s
```
The disk is now ready to be used.  
You can use the *alpine_vm_clone1_wo_cloudinit.yaml* file this time. As the boot disk was already customized, no need to go through similar step this time:  
```bash
$ kubectl create -f alpine_vm_clone1_wo_cloudinit.yaml -n sc26-alpine-c
virtualmachine.kubevirt.io/alpine-vm-clone created
```
The result would look like the following:  
```bash
$ kubectl get -n sc26-alpine-c all,pvc
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                      READY   STATUS    RESTARTS   AGE
pod/virt-launcher-alpine-vm-4g7jn         2/2     Running   0          57s
pod/virt-launcher-alpine-vm-clone-r76fm   2/2     Running   0          2m53s

NAME                                           PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot         Succeeded   N/A                   66m
datavolume.cdi.kubevirt.io/alpine-boot-clone   Succeeded   100.0%                7m22s

NAME                                                 AGE     PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-vm         58s     Running   192.168.28.73   rhel2      True
virtualmachineinstance.kubevirt.io/alpine-vm-clone   2m54s   Running   192.168.26.13   rhel1      True

NAME                                         AGE     STATUS    READY
virtualmachine.kubevirt.io/alpine-vm         63m     Running   True
virtualmachine.kubevirt.io/alpine-vm-clone   2m54s   Running   True

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot         Bound    pvc-dedf8d1e-ae3e-4f84-bfe4-ca5a3d9ab446   1Gi        RWX            storage-class-iscsi   <unset>                 66m
persistentvolumeclaim/alpine-boot-clone   Bound    pvc-b21e6444-ddcf-4aa6-a893-71653fbbb2a2   1Gi        RWX            storage-class-iscsi   <unset>                 7m22s
```
Finally, let's connect to the new VM:  
```bash
$ virtctl console -n sc26-alpine-c alpine-vm-clone
Successfully connected to alpine-vm-clone console. Press Ctrl+] or Ctrl+5 to exit console.

Welcome to Alpine Linux 3.22
Kernel 6.12.38-0-virt on x86_64 (/dev/ttyS0)

alpine-vm-clone.sc26-alpine-c.svc.cluster.local login: alpine
Password:
Welcome to Alpine on KubeVirt in the NetApp LoD!
```
If you managed to log in the VM with the correct password (alpine), and if you see the same message, the prooves you are running with a copy of a disk that was already tailored.  


## B. Cloning to a different namespace (strategy: copy) 
<a name="method2"></a>

First step, let's create a new namespace called _sc26-alpine-d_.  
```bash
$ kubectl create  ns sc26-alpine-d
namespace/sc26-alpine-d created
```
Let's directly create a dataVolume:  
Let's see how to create a clone of the existing Virtual Machine using a DataVolume:  
```bash
$ cat << EOF | kubectl apply  -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: alpine-boot-clone
  namespace: sc26-alpine-d
  labels:
    method: clone2
spec:
  pvc:
    accessModes:
      - ReadWriteMany
    resources:
      requests:
        storage: 1Gi
    volumeMode: Block
    storageClassName: storage-class-iscsi
  contentType: kubevirt
  source:
    pvc:
      name: alpine-boot
      namespace: sc26-alpine-c
EOF
datavolume.cdi.kubevirt.io/alpine-boot-clone created
```
The source of the copy being in the _sc26-alpine-c_ namespace, 2 temporary pods are created there.  
You can read there logs here:  
```bash
$ kubectl logs -n sc26-alpine-c cdi-upload-tmp-pvc-e8e705f3-9862-4981-b47c-7f5afda3ff63 -f
I1111 11:37:38.826990       1 uploadserver.go:81] Running server on 0.0.0.0:8443
I1111 11:37:49.323310       1 uploadserver.go:410] Content type header is "blockdevice-clone"
I1111 11:37:49.331934       1 file.go:230] copyWithSparseCheck to /dev/cdi-block-volume
I1111 11:38:08.023151       1 file.go:195] Read 1073741824 bytes, wrote 120291328 bytes to /dev/cdi-block-volume
I1111 11:38:08.023725       1 uploadserver.go:436] Wrote data to /dev/cdi-block-volume
I1111 11:38:08.024242       1 uploadserver.go:215] Shutting down http server after successful upload
I1111 11:38:08.029633       1 uploadserver.go:115] UploadServer successfully exited

$ kubectl logs -n sc26-alpine-c 627902f9-6f12-46bb-a938-8ad69e862c4c-source-pod -f
VOLUME_MODE=block
MOUNT_POINT=/dev/cdi-block-volume
UPLOAD_BYTES=1073741824
I1111 11:37:48.931421       3 clone-source.go:223] content-type is "blockdevice-clone"
I1111 11:37:48.931687       3 clone-source.go:224] mount is "/dev/cdi-block-volume"
I1111 11:37:48.931718       3 clone-source.go:225] upload-bytes is 1073741824
I1111 11:37:48.931759       3 clone-source.go:242] Starting cloner target
I1111 11:37:49.303065       3 clone-source.go:258] Set header to blockdevice-clone
I1111 11:37:49.932363       3 prometheus.go:78] 5.67
...
I1111 11:38:07.954927       3 prometheus.go:78] 99.67
I1111 11:38:08.010452       3 clone-source.go:127] Wrote 1073741824 bytes
I1111 11:38:08.025669       3 clone-source.go:276] Response body:
I1111 11:38:08.026122       3 clone-source.go:278] clone complete
```
As in the previous examples, you will also get a temporary PVC in the target namespace.  
Once the copy is done, you will end up with a datavolume and a pvc:  
```bash
$ kubectl get all,pvc -n sc26-alpine-d
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                           PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot-clone   Succeeded   100.0%                100s

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-clone   Bound    pvc-627902f9-6f12-46bb-a938-8ad69e862c4c   1Gi        RWX            storage-class-iscsi   <unset>                 99s
```
If desired, you can also create a VM on top of this volume, and connect to its console to check the content with the following:  
```bash
kubectl create -f alpine_vm_clone2_wo_cloudinit.yaml -n sc26-alpine-d
virtctl console -n sc26-alpine-d alpine-vm-clone
```

## C. Cloning within the same namespace (strategy: snapshot) 
<a name="method3"></a>

Main requirement, you need a Volume Snapshot Class:  
```bash
$ kubectl create -f ../../../Scenario13/1_CSI_Snapshots/sc-volumesnapshot.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class created
```
The CDI automatically updated the storageProfile:  
```bash
$ kubectl get storageprofile storage-class-iscsi -o yaml
apiVersion: cdi.kubevirt.io/v1beta1
kind: StorageProfile
metadata:
  creationTimestamp: "2025-11-10T15:05:18Z"
  generation: 2
  labels:
    app: containerized-data-importer
    app.kubernetes.io/component: storage
    app.kubernetes.io/managed-by: cdi-controller
    cdi.kubevirt.io: ""
  name: storage-class-iscsi
...
status:
  claimPropertySets:
  - accessModes:
    - ReadWriteMany
    volumeMode: Block
  cloneStrategy: snapshot
  dataImportCronSourceFormat: snapshot
  provisioner: csi.trident.netapp.io
  snapshotClass: csi-snap-class
  storageClass: storage-class-iscsi
```
Notice the **cloneStrategy** and **dataImportCronSourceFormat** which were updated to _snapshot_?  

Let's create a new DataVolume:  
```bash
$ cat << EOF | kubectl apply  -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: alpine-boot-clone
  namespace: sc26-alpine-c
  labels:
    method: clone3
spec:
  pvc:
    accessModes:
      - ReadWriteMany
    resources:
      requests:
        storage: 1Gi
    volumeMode: Block
    storageClassName: storage-class-iscsi
  contentType: kubevirt
  source:
    pvc:
      name: alpine-boot
      namespace: sc26-alpine-c
EOF
datavolume.cdi.kubevirt.io/alpine-boot-clone created
```
If you are fast enough, you will see a temporary Volume Snapshot:  
```bash
$ kubectl get -n sc26-alpine-c vs
NAME                                                READYTOUSE   SOURCEPVC     SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
tmp-snapshot-49f5ffe4-a6f5-49ad-9ca9-002e83f15b2b   true         alpine-boot                           1Gi           csi-snap-class   snapcontent-01c3e902-cf4c-475d-89eb-f819c023bda4   13s            13s
```
Pretty quickly, a new PVC will be able, built from the snapshot, at which point, the snapshot will be deleted:  
```bash
$ kubectl get -n sc26-alpine-c all,pvc,vs -l method=clone3
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                           PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot-clone   Succeeded   100.0%                4m55s

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-clone   Bound    pvc-8b10bfd3-6a08-474b-9d01-012e776cbe2e   1Gi        RWX            storage-class-iscsi   <unset>                 4m55s
```
In the backend, creating a PVC from the snapshot uses the NetApp FlexClone feature, one of the reasons the operation was so fast... Deleting the snapshot triggers a split clone, so that the volume corresponding to the PVC becomes detached from its parent volume.  

If desired, you can also create a VM on top of this volume, and connect to its console to check the content with the following:  
```bash
kubectl create -f alpine_vm_clone3_wo_cloudinit.yaml -n sc26-alpine-c
virtctl console -n sc26-alpine-d alpine-vm-clone
```

## D. Cloning to a different namespace (strategy: snapshot) 
<a name="method4"></a>

First step, let's create a new namespace called _sc26-alpine-d_.  
```bash
$ kubectl create  ns sc26-alpine-e
namespace/sc26-alpine-e created
```

We can directly move to the datavolume creation:  

Let's create a new DataVolume:  
```bash
$ cat << EOF | kubectl apply  -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: alpine-boot-clone
  namespace: sc26-alpine-e
  labels:
    method: clone4
spec:
  pvc:
    accessModes:
      - ReadWriteMany
    resources:
      requests:
        storage: 1Gi
    volumeMode: Block
    storageClassName: storage-class-iscsi
  contentType: kubevirt
  source:
    pvc:
      name: alpine-boot
      namespace: sc26-alpine-c
EOF
datavolume.cdi.kubevirt.io/alpine-boot-clone created
```
Following the same logic as in the previous chapters, you will see a temporary snapshot in the source volume, and the corresponding new PVC & DV in the new namespace:  
```bash
$ kubectl get vs -n sc26-alpine-c
NAME                                                READYTOUSE   SOURCEPVC     SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
tmp-snapshot-eefa8c0a-a136-4093-824d-ec95bee20d48   true         alpine-boot                           1Gi           csi-snap-class   snapcontent-e10a23ee-488c-40f8-820a-9eb1a5bd9b3f   24s            24s

$ kubectl get all,pvc -n sc26-alpine-e
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                           PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot-clone   Succeeded   100.0%                10s

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-clone   Bound    pvc-2386abdb-d789-4308-862b-64f5f115f98c   1Gi        RWX            storage-class-iscsi   <unset>                 10s
```
If desired, you can also create a VM on top of this volume, and connect to its console to check the content with the following:  
```bash
kubectl create -f alpine_vm_clone4_wo_cloudinit.yaml -n sc26-alpine-e
virtctl console -n sc26-alpine-e alpine-vm-clone
```

## E. Clean up

Let's remove some of the things we created:  
```bash
kubectl delete ns sc26-alpine-e sc26-alpine-d sc26-alpine-c
```