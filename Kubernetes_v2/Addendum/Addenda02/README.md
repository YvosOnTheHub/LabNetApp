#########################################################################################
# ADDENDA 2: Specify a default storage class
#########################################################################################

**GOAL:**  
Most of the volume requests in this lab refer to a specific storage class.  
Setting a _default_ storage class can be useful, especially when this one is used most times.
This also allows you not to set the storage class parameter in the Volume Claim anymore.

## A. Set a default storage class
```
# kubectl get sc
NAME                        PROVISIONER             AGE

storage-class-nas           csi.trident.netapp.io   3d18h
storage-class-nas-economy   csi.trident.netapp.io   3d18h

# kubectl patch storageclass storage-class-nas -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
storageclass.storage.k8s.io/storage-class-nas patched

# kubectl get sc
NAME                          PROVISIONER             AGE
storage-class-nas (default)   csi.trident.netapp.io   3d18h
storage-class-nas-economy     csi.trident.netapp.io   3d18h
```
As you can see, _storage-class-nas_ is now refered as the default SC for this cluster.

## B. Try this new setup

There is a PVC file in this directory. If you look at it, you will see there is no SC set.  
```
# kubectl create -f 1_pvc.yaml
persistentvolumeclaim/pvc-without-sc created

# kubectl get pvc,pv
NAME                                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/pvc-without-sc   Bound    pvc-517348e4-8201-4ac0-a9e1-4adfa5c38f1e   5Gi        RWX            storage-class-nas   6s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS        REASON   AGE
persistentvolume/pvc-517348e4-8201-4ac0-a9e1-4adfa5c38f1e   5Gi        RWX            Delete           Bound    default/pvc-without-sc   storage-class-nas            5s
```
If you take a closer look at the _get pv_ result, you will see that it shows the storage class against which it was created, which is also the default one.
```
# kubectl delete pvc pvc-without-sc
persistentvolumeclaim "pvc-without-sc" deleted
```


## C. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?