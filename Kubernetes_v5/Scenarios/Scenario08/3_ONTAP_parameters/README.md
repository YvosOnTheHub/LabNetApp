#########################################################################################
# SCENARIO 8: Consumption control: ONTAP parameters
#########################################################################################

The amount of ONTAP volumes (Flexvols) you can have on a ONTAP cluster depends on several parameters:

- version
- size of the ONTAP cluster (in terms of controllers)  

If the storage platform is also used by other workloads (Databases, Files Services ...), you may want to limit the number of PVC you build in your storage Tenant (ie SVM)
This can be achieved by setting a parameter on this SVM.  
https://docs.netapp.com/us-en/trident/trident-reco/storage-config-best-practices.html#limit-the-maximum-volume-count  

<p align="center"><img src="../Images/scenario08_4.JPG"></p>

Before setting a limit in the SVM _nfs_svm_, you first need to look for the current number of volumes you have.
You can either login to System Manager & count, or run the following (password Netapp1!)

```bash
ssh -l admin 192.168.0.101 vol show -vserver nfs_svm | grep nfs_svm | wc -l
```

In my case, I have 10 volumes, I will then set the maximum to 12 for this exercise.

```bash
ssh -l admin 192.168.0.101 vserver modify -vserver nfs_svm -max-volumes 12
```

If you would like to check if the command has well been taken into account, you can run the following command:

```bash
$ ssh -l admin 192.168.0.101 vserver show -vserver nfs_svm -fields max-volumes
vserver    max-volumes
-------    -----------
nfs_svm    12
```

Let's try to create a few new PVC.

```bash
$ kubectl create -f pvc-ontap-1.yaml
persistentvolumeclaim/ontaplimit-1 created
$ kubectl create -f pvc-ontap-2.yaml
persistentvolumeclaim/ontaplimit-2 created
$ kubectl create -f pvc-ontap-3.yaml
persistentvolumeclaim/ontaplimit-3 created

$ kubectl get pvc  -l scenario=ontap
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
ontaplimit-1   Bound     pvc-a74622aa-bb26-4796-a624-bf6d72955de8   1Gi        RWX            storage-class-nas   92s
ontaplimit-2   Bound     pvc-f2bd901a-35e8-45a1-8294-2135b56abe19   1Gi        RWX            storage-class-nas   22s
ontaplimit-3   Pending                                                                        storage-class-nas   4s
```

The PVC will remain in the _Pending_ state. You need to look either in the PVC logs or Trident's

```bash
$ kubectl describe pvc ontaplimit-3
...
 Warning  ProvisioningFailed    15s  
 API status: failed, Reason: Cannot create volume. Reason: Maximum volume count for Vserver nfs_svm reached.  Maximum volume count is 12. , Code: 13001
...
```

There you go, point demonstrated!

Time to clean up

```bash
$ kubectl delete pvc -l scenario=ontap
persistentvolumeclaim "ontaplimit-1" deleted
persistentvolumeclaim "ontaplimit-2" deleted
persistentvolumeclaim "ontaplimit-3" deleted
```

## D. What's next

You can now move on to the next section of this chapter: [a bit of everything](../4_A_bit_of_everything)

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)