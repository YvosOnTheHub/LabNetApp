#########################################################################################
# ADDENDA 2: Specify a default storage class
#########################################################################################

**GOAL:**  
Most of the volume requests in this lab refer to a specific storage class.  
Setting a _default_ storage class can be useful, especially when this one is used most times.
This also allows you not to set the storage class parameter in the Volume Claim anymore.

## A. Set a default storage class

```bash
$ kubectl get sc
NAME                          PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storage-class-iscsi         csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-nfs           csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-nvme          csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-smb           csi.trident.netapp.io   Delete          Immediate           true                   75d

$ kubectl patch storageclass storage-class-nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
storageclass.storage.k8s.io/storage-class-nfs patched

$ kubectl get sc
NAME                          PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storage-class-iscsi           csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-nfs (default)   csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-nvme            csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-smb             csi.trident.netapp.io   Delete          Immediate           true                   75d
```

As you can see, _storage-class-nfs_ is now refered as the default SC for this cluster.

## B. Try this new setup

There is a PVC file in this directory. If you look at it, you will see there is no SC set.  

```bash
$ kubectl create -f 1_pvc.yaml
persistentvolumeclaim/pvc-without-sc created

$ kubectl get pvc,pv
NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/pvc-without-sc   Bound    pvc-17c42930-9bf6-4ef6-abc8-d65400140699   5Gi        RWX            storage-class-nfs   <unset>                 15s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS        VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-17c42930-9bf6-4ef6-abc8-d65400140699   5Gi        RWX            Delete           Bound    default/pvc-without-sc   storage-class-nfs   <unset>                          13s
```

If you take a closer look at the _get pv_ result, you will see that it shows the storage class against which it was created, which is also the default one.

```bash
$ kubectl delete pvc pvc-without-sc
persistentvolumeclaim "pvc-without-sc" deleted
```

## C. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?