#########################################################################################
# SCENARIO 8: Consumption control: Mixing them all
#########################################################################################

There are plenty of ways to control storage consumptions.  
We have seen them individually in the previous chapters, let's combine some of them.  

In the following example, we will use:  
- Trident driver: ONTAP-NAS-ECONOMY
- Trident backend parameter: limitVolumePoolSize (10GB)
- ONTAP parameter: max number of volumes per SVM

:boom:  
Trident 24.06 introduced the _limitVolumePoolSize_, which replaces the _limitVolumeSize_ behavior when it comes to ECONOMY drivers.
:boom:  

## A. Trident Configuration

We are going to create a specific Trident backend & a specific storage class for this scenario.  
```bash
$ kubectl create -n trident -f backend_nas-limitpoolsize.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-eco-limit-poolsize created

$ kubectl create -f sc-eco-limit.yaml
storageclass.storage.k8s.io/sc-eco-limit created
```

## B. ONTAP Configuration

Let's see how many volumes are currently present, and let's create a limit to allow the creation of 2 extra volumes.

```bash
ssh -l admin 192.168.0.101 vol show -vserver nassvm | grep entries | head -c 1; echo
```

In my case, I have 2 volumes, I will then set the maximum to 4 for this exercise.  
```bash
ssh -l admin 192.168.0.101 vserver modify -vserver nassvm -max-volumes 4
```

If you would like to check if the command has well been taken into account, you can run the following command:
```bash
$ ssh -l admin 192.168.0.101 vserver show -vserver nassvm -fields max-volumes
vserver   max-volumes
-------   -----------
nassvm    4
```

## C. Let's try this!

We will start by creating 4x4GB PVC.  
As the limit for the volume hosting the qtrees is 10GB, we should end up with 2 new FlexVol, each one with 2 Qtrees (PVC).  
```bash
$ kubectl create -f pvc_4Gb_1_to_4.yaml
persistentvolumeclaim/4gb-1 created
persistentvolumeclaim/4gb-2 created
persistentvolumeclaim/4gb-3 created
persistentvolumeclaim/4gb-4 created

$ kubectl get pvc -l scenario=sc8_4
NAME    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
4gb-1   Bound    pvc-6dce975e-9267-4779-a63d-2e4aee826146   4Gi        RWX            sc-eco-limit   22s
4gb-2   Bound    pvc-08b624a5-bcf2-4e9e-a40c-7697f6400dea   4Gi        RWX            sc-eco-limit   22s
4gb-3   Bound    pvc-2069b568-faf2-4cf3-a6a9-775e74f143af   4Gi        RWX            sc-eco-limit   22s
4gb-4   Bound    pvc-efda54be-ccfb-4b08-af98-87ce6adee7dd   4Gi        RWX            sc-eco-limit   22s
```

Let's see what we find on the storage backend.  
Open a new terminal to connect to ONTAP via ssh (192.168.0.133 & user vsadmin/Netapp1!)
```bash
$ qtree show -vserver nassvm -volume trident* -qtree sc08*
Vserver    Volume        Qtree        Style        Oplocks   Status
---------- ------------- ------------ ------------ --------- --------
nassvm     trident_qtree_pool_sc08_4_CZGYFIQXXL
                         sc08_4_pvc_8c362264_2059_46cf_b321_3d34f253cec3
                                      unix         enable    normal
nassvm     trident_qtree_pool_sc08_4_CZGYFIQXXL
                         sc08_4_pvc_9793007d_0d19_4b7b_926d_a5909f32d0fe
                                      unix         enable    normal
nassvm     trident_qtree_pool_sc08_4_SVOAKAFOYQ
                         sc08_4_pvc_67df7bd2_1179_4709_8fd0_0b979208be49
                                      unix         enable    normal
nassvm     trident_qtree_pool_sc08_4_SVOAKAFOYQ
                         sc08_4_pvc_e3c334ee_ec7c_4a03_b745_8275b8db94c1
                                      unix         enable    normal
4 entries were displayed.

$ df -h -volume trident* -vserver nassvm
Filesystem               total       used      avail capacity  Mounted on
/vol/trident_qtree_pool_sc08_4_CZGYFIQXXL/
                        8192MB      316KB     8191MB       0%  /trident_qtree_pool_sc08_4_CZGYFIQXXL
/vol/trident_qtree_pool_sc08_4_CZGYFIQXXL/.snapshot
                            0B         0B         0B       0%  /trident_qtree_pool_sc08_4_CZGYFIQXXL/.snapshot
/vol/trident_qtree_pool_sc08_4_SVOAKAFOYQ/
                        8192MB      316KB     8191MB       0%  /trident_qtree_pool_sc08_4_SVOAKAFOYQ
/vol/trident_qtree_pool_sc08_4_SVOAKAFOYQ/.snapshot
                            0B         0B         0B       0%  /trident_qtree_pool_sc08_4_SVOAKAFOYQ/.snapshot
4 entries were displayed.

$ quota report -volume trident* -vserver nassvm
Vserver: nassvm

                                    ----Disk----  ----Files-----   Quota
Volume   Tree      Type    ID        Used  Limit    Used   Limit   Specifier
-------  --------  ------  -------  -----  -----  ------  ------   ---------
trident_qtree_pool_sc08_4_CZGYFIQXXL
         sc08_4_pvc_9793007d_0d19_4b7b_926d_a5909f32d0fe
                   tree    1           0B    4GB       1       -   sc08_4_pvc_9793007d_0d19_4b7b_926d_a5909f32d0fe
trident_qtree_pool_sc08_4_CZGYFIQXXL
         sc08_4_pvc_8c362264_2059_46cf_b321_3d34f253cec3
                   tree    2           0B    4GB       1       -   sc08_4_pvc_8c362264_2059_46cf_b321_3d34f253cec3
trident_qtree_pool_sc08_4_CZGYFIQXXL
                   tree    *           0B      -       0       -   *
trident_qtree_pool_sc08_4_SVOAKAFOYQ
         sc08_4_pvc_e3c334ee_ec7c_4a03_b745_8275b8db94c1
                   tree    1           0B    4GB       1       -   sc08_4_pvc_e3c334ee_ec7c_4a03_b745_8275b8db94c1
trident_qtree_pool_sc08_4_SVOAKAFOYQ
         sc08_4_pvc_67df7bd2_1179_4709_8fd0_0b979208be49
                   tree    2           0B    4GB       1       -   sc08_4_pvc_67df7bd2_1179_4709_8fd0_0b979208be49
trident_qtree_pool_sc08_4_SVOAKAFOYQ
                   tree    *           0B      -       0       -   *
6 entries were displayed.
```

As expected, we have 2 new volumes, each one with 2 qtrees.  
Also, notice that the PVC sizes are translated into Qtree Quotas in ONTAP & the size of the ONTAP Volume is the sum of all Qtree Quotas.  
Now, let's create another PVC.  
```bash
$ kubectl create -f pvc_4Gb_5.yaml
persistentvolumeclaim/4gb-5 created

$ kubectl get pvc -l scenario=sc8_4
NAME    STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
4gb-1   Bound     pvc-6dce975e-9267-4779-a63d-2e4aee826146   4Gi        RWX            sc-eco-limit   22s
4gb-2   Bound     pvc-08b624a5-bcf2-4e9e-a40c-7697f6400dea   4Gi        RWX            sc-eco-limit   22s
4gb-3   Bound     pvc-2069b568-faf2-4cf3-a6a9-775e74f143af   4Gi        RWX            sc-eco-limit   22s
4gb-4   Bound     pvc-efda54be-ccfb-4b08-af98-87ce6adee7dd   4Gi        RWX            sc-eco-limit   22s
4gb-5   Pending                                                                        sc-eco-limit   23s

$ kubectl describe pvc 4gb-5
Name:          4gb-5
Namespace:     default
StorageClass:  sc-eco-limit
Status:        Pending
Volume:
Labels:        scenario=sc8_4
Annotations:   volume.beta.kubernetes.io/storage-provisioner: csi.trident.netapp.io
               volume.kubernetes.io/storage-provisioner: csi.trident.netapp.io
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:
Access Modes:
VolumeMode:    Filesystem
Used By:       <none>
Events:
  Type     Reason                Age                From                                                                                            Message
  ----     ------                ----               ----                                                                                            -------
  Normal   Provisioning          12s (x2 over 20s)  csi.trident.netapp.io_trident-controller-5bf59dc7c6-mtn7d_7d7e553b-dab8-4e8c-aae0-243952c527e8  External provisioner is provisioning volume for claim "default/4gb-5"
  Warning  ProvisioningFailed    12s (x2 over 20s)  csi.trident.netapp.io_trident-controller-5bf59dc7c6-mtn7d_7d7e553b-dab8-4e8c-aae0-243952c527e8  failed to provision volume with StorageClass "sc-eco-limit": rpc error: code = Unknown desc = encountered error(s) in creating the volume: [Failed to create volume pvc-f3016171-5d79-42bd-b368-ca48ddb4041c on storage pool aggr1 from backend nas-eco-limit-poolsize: backend cannot satisfy create request for volume sc08_4_pvc_f3016171_5d79_42bd_b368_ca48ddb4041c: (ONTAP-NAS-QTREE pool aggr1/aggr1; Flexvol location/creation failed sc08_4_pvc_f3016171_5d79_42bd_b368_ca48ddb4041c: error creating Flexvol for qtree: error creating Flexvol: API status: failed, Reason: Cannot create volume. Reason: Maximum volume count for Vserver nassvm reached.  Maximum volume count is 4. , Code: 13001)]
  Normal   ExternalProvisioning  6s (x3 over 19s)   persistentvolume-controller                                                                     Waiting for a volume to be created either by the external provisioner 'csi.trident.netapp.io' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
```

Again, as expected, the creation of the 5th PVC has failed because we have reached the maximum amount of volumes on the backend.  
In this very case, the user can ask very nicely the admin to increase the limit.  
```bash
$ kubectl delete pvc 4gb-5
persistentvolumeclaim "4gb-5" deleted

$ ssh -l admin 192.168.0.101 vserver modify -vserver nassvm -max-volumes 5

$ kubectl create -f pvc5.yaml
persistentvolumeclaim/4gb-5 created

$ kubectl get pvc -l scenario=sc8_4
NAME    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
4gb-1   Bound    pvc-6dce975e-9267-4779-a63d-2e4aee826146   4Gi        RWX            sc-eco-limit   55m
4gb-2   Bound    pvc-08b624a5-bcf2-4e9e-a40c-7697f6400dea   4Gi        RWX            sc-eco-limit   55m
4gb-3   Bound    pvc-2069b568-faf2-4cf3-a6a9-775e74f143af   4Gi        RWX            sc-eco-limit   55m
4gb-4   Bound    pvc-efda54be-ccfb-4b08-af98-87ce6adee7dd   4Gi        RWX            sc-eco-limit   55m
4gb-5   Bound    pvc-2d0ca65d-fcf9-4322-9b4e-a7bbb9aa91fd   4Gi        RWX            sc-eco-limit   20s
```
There you go. The change was taken into account immediately, & the volume creation succeeded.  

Let's clean up before moving on.  
```bash
$ kubectl delete pvc -l scenario=sc8_4
persistentvolumeclaim "4gb-1" deleted
persistentvolumeclaim "4gb-2" deleted
persistentvolumeclaim "4gb-3" deleted
persistentvolumeclaim "4gb-4" deleted
persistentvolumeclaim "4gb-5" deleted
$ kubectl delete sc sc-eco-limit
storageclass.storage.k8s.io "sc-eco-limit" deleted
$ kubectl delete -n trident tbc backend-tbc-ontap-nas-eco-limit-poolsize
tridentbackendconfig.trident.netapp.io "backend-tbc-ontap-nas-eco-limit-poolsize" deleted
```

## D. Conclusion

Using this method allows you to manage capacity with Building Blocks.  
You could decide to allocate one or several _FlexVol_ per tenant, & grow the limit when requested, while limiting the size of each PVC.

:mag:  
**Keep in mind that each Storage Tenant (SVM) always has a root volume.  
The smallest number you can set for the maximum number of volumes is then 2.**  
:mag_right:  

**Some examples:**

1. ONTAP-NAS-ECONOMY & LimitVolumePoolSize = 1TB & Max Number of Volumes = 2  
You can create up to 200 PVC until you reach 1TB of capacity.  
The Kubernetes admin could update the Trident backend to grow the limit from 1TB to 2TB.

2. ONTAP-NAS-ECONOMY & LimitVolumePoolSize = 1TB & Max Number of Volumes = 5  
You can create up to 800 PVC (4x200) until you reach 4TB of capacity, divided in 4 ONTAP volumes.  
The storage admin could update the ONTAP parameter to create a new 1TB ONTAP volume.  

## E. What's next

You can now move on to the next section of this chapter: [What about CSI Snapshots](../5_What_about_csi_snapshots)

Or you can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp) to choose another scenario.