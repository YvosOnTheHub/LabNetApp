#########################################################################################
# SCENARIO 8: Consumption control: Mixing them all
#########################################################################################

There are plenty of ways to control storage consumptions.  
We have seen them individually in the previous chapters, let's combine some of them.  

In the following example, we will use:

- Trident driver: ONTAP-NAS-ECONOMY
- Trident backend parameter: limitVolumeSize (10GB)
- ONTAP parameter: max number of volumes per SVM

:boom:  
With Trident 20.10, you can now specify how many Qtrees (PVC) you can have per ONTAP volume when using the ONTAP-NAS-ECONOMY driver.  
Default value: 200.  
Range: between 50 & 300.  
For more information, see https://docs.netapp.com/us-en/trident/trident-use/ontap-nas-examples.html#backend-configuration-options  
:boom:  

## A. Trident Configuration

We are going to create a specific Trident backend & a specific storage class for this scenario.  

```bash
$ kubectl create -n trident -f backend_nas-limitvolumesize.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-eco-limit-volsize created

$ kubectl create -f sc-eco-limit.yaml
storageclass.storage.k8s.io/sc-eco-limit created
```

## B. ONTAP Configuration

Let's see how many volumes are currently present, and let's create a limit to allow the creation of 2 extra volumes.

```bash
ssh -l admin 192.168.0.101 vol show -vserver nfs_svm | grep nfs_svm | wc -l
```

In my case, I have 5 volumes, I will then set the maximum to 7 for this exercise.

```bash
ssh -l admin 192.168.0.101 vserver modify -vserver nfs_svm -max-volumes 7
```

If you would like to check if the command has well been taken into account, you can run the following command:

```bash
$ ssh -l admin 192.168.0.101 vserver show -vserver nfs_svm -fields max-volumes
vserver   max-volumes
-------   -----------
nfs_svm   7
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

```bash
$ ssh -l vsadmin 192.168.0.135 qtree show -volume trident* -qtree sc08*
Vserver    Volume        Qtree        Style        Oplocks   Status
---------- ------------- ------------ ------------ --------- --------
nfs_svm    trident_qtree_pool_sc08_4_WLBUCEQRMW sc08_4_pvc_2069b568_faf2_4cf3_a6a9_775e74f143af unix enable normal
nfs_svm    trident_qtree_pool_sc08_4_WLBUCEQRMW sc08_4_pvc_efda54be_ccfb_4b08_af98_87ce6adee7dd unix enable normal
nfs_svm    trident_qtree_pool_sc08_4_YFTRSVZKLG sc08_4_pvc_08b624a5_bcf2_4e9e_a40c_7697f6400dea unix enable normal
nfs_svm    trident_qtree_pool_sc08_4_YFTRSVZKLG sc08_4_pvc_6dce975e_9267_4779_a63d_2e4aee826146 unix enable normal
4 entries were displayed.

$ ssh -l vsadmin 192.168.0.135 df -h -volume trid*
Filesystem               total       used      avail capacity  Mounted on
/vol/trident_qtree_pool_sc08_4_WLBUCEQRMW/ 8192MB 296KB 8191MB 0%  /trident_qtree_pool_sc08_4_WLBUCEQRMW
/vol/trident_qtree_pool_sc08_4_WLBUCEQRMW/.snapshot 0B 0B 0B 0%  /trident_qtree_pool_sc08_4_WLBUCEQRMW/.snapshot
/vol/trident_qtree_pool_sc08_4_YFTRSVZKLG/ 8192MB 296KB 8191MB 0%  /trident_qtree_pool_sc08_4_YFTRSVZKLG
/vol/trident_qtree_pool_sc08_4_YFTRSVZKLG/.snapshot 0B 0B 0B 0%  /trident_qtree_pool_sc08_4_YFTRSVZKLG/.snapshot
4 entries were displayed.

$ ssh -l vsadmin 192.168.0.135 quota report -volume trident_qtree_pool_sc08*
                                                                                                        ----Disk----  ----Files-----   Quota
Volume                                Tree                                             Type    ID       Used   Limit    Used   Limit   Specifier
-------                               --------                                         ------  -------  -----  -----  ------  ------   ---------
trident_qtree_pool_sc08_4_WLBUCEQRMW  sc08_4_pvc_2069b568_faf2_4cf3_a6a9_775e74f143af  tree    1        0B     4GB    1       -        sc08_4_pvc_2069b568_faf2_4cf3_a6a9_775e74f143af
trident_qtree_pool_sc08_4_WLBUCEQRMW  sc08_4_pvc_efda54be_ccfb_4b08_af98_87ce6adee7dd  tree    2        0B     4GB    1       -        sc08_4_pvc_efda54be_ccfb_4b08_af98_87ce6adee7dd
trident_qtree_pool_sc08_4_WLBUCEQRMW                                                   tree    *        0B     -      0       -        *
trident_qtree_pool_sc08_4_YFTRSVZKLG  sc08_4_pvc_08b624a5_bcf2_4e9e_a40c_7697f6400dea  tree    1        0B     4GB    1       -        sc08_4_pvc_08b624a5_bcf2_4e9e_a40c_7697f6400dea
trident_qtree_pool_sc08_4_YFTRSVZKLG  sc08_4_pvc_6dce975e_9267_4779_a63d_2e4aee826146  tree    2        0B     4GB    1       -        sc08_4_pvc_6dce975e_9267_4779_a63d_2e4aee826146
trident_qtree_pool_sc08_4_YFTRSVZKLG                                                   tree    *        0B     -      0       -        *
6 entries were displayed.

$ ssh -l vsadmin 192.168.0.135 df -h trident_qtree_pool_sc08*
Filesystem               total       used      avail capacity  Mounted on
/vol/trident_qtree_pool_sc08_4_WLBUCEQRMW/ 8192MB 316KB 8191MB 0%  /trident_qtree_pool_sc08_4_WLBUCEQRMW
/vol/trident_qtree_pool_sc08_4_WLBUCEQRMW/.snapshot 0B 0B 0B 0%  /trident_qtree_pool_sc08_4_WLBUCEQRMW/.snapshot
/vol/trident_qtree_pool_sc08_4_YFTRSVZKLG/ 8192MB 308KB 8191MB 0%  /trident_qtree_pool_sc08_4_YFTRSVZKLG
/vol/trident_qtree_pool_sc08_4_YFTRSVZKLG/.snapshot 0B 0B 0B 0%  /trident_qtree_pool_sc08_4_YFTRSVZKLG/.snapshot
4 entries were displayed.
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
...
Events:
  Type     Reason                Age                 From                                                                                     Message
  ----     ------                ----                ----                                                                                     -------
  Normal   Provisioning          53s (x7 over 116s)  csi.trident.netapp.io_trident-csi-7f4f878c58-6whlb_3118ff8e-4be0-448d-8f20-2701166c6bc7  External provisioner is provisioning volume for claim "default/4gb-5"
  Normal   ProvisioningFailed    53s (x7 over 115s)  csi.trident.netapp.io                                                                    encountered error(s) in creating the volume: [Failed to create volume pvc-48c9eb18-c414-4af8-904c-1f00d343878e on storage pool aggr1 from backend nas-eco-limit-volsize: backend cannot satisfy create request for volume sc08_4_pvc_48c9eb18_c414_4af8_904c_1f00d343878e: (ONTAP-NAS-QTREE pool aggr1/aggr1; Flexvol location/creation failed sc08_4_pvc_48c9eb18_c414_4af8_904c_1f00d343878e: error creating Flexvol for qtree: error creating Flexvol: API status: failed, Reason: Cannot create volume. Reason: Maximum volume count for Vserver nfs_svm reached.  Maximum volume count is 7. , Code: 13001)]
  Warning  ProvisioningFailed    53s (x7 over 115s)  csi.trident.netapp.io_trident-csi-7f4f878c58-6whlb_3118ff8e-4be0-448d-8f20-2701166c6bc7  failed to provision volume with StorageClass "sc-eco-limit": rpc error: code = Unknown desc = encountered error(s) in creating the volume: [Failed to create volume pvc-48c9eb18-c414-4af8-904c-1f00d343878e on storage pool aggr1 from backend nas-eco-limit-volsize: backend cannot satisfy create request for volume sc08_4_pvc_48c9eb18_c414_4af8_904c_1f00d343878e: (ONTAP-NAS-QTREE pool aggr1/aggr1; Flexvol location/creation failed sc08_4_pvc_48c9eb18_c414_4af8_904c_1f00d343878e: error creating Flexvol for qtree: error creating Flexvol: API status: failed, Reason: Cannot create volume. Reason: Maximum volume count for Vserver nfs_svm reached.  Maximum volume count is 7. , Code: 13001)]
  Normal   ExternalProvisioning  12s (x8 over 116s)  persistentvolume-controller                                                              waiting for a volume to be created, either by external provisioner "csi.trident.netapp.io" or manually created by system administrator
```

Again, as expected, the creation of the 5th PVC has failed because we have reached the maximum amount of volumes on the backend.  
In this very case, the user can ask very nicely the admin to increase the limit

```bash
$ kubectl delete pvc 4gb-5
persistentvolumeclaim "4gb-5" deleted

$ ssh -l admin 192.168.0.101 vserver modify -vserver nfs_svm -max-volumes 8

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
$ kubectl delete -n trident tbc backend-tbc-ontap-nas-eco-limit-volsize
tridentbackendconfig.trident.netapp.io "backend-tbc-ontap-nas-limit-aggr" deleted
```

## D. Conclusion

Using this method allows you to manage capacity with Building Blocks.  
You could decide to allocate one or several _FlexVol_ per tenant, & grow the limit when requested, while limiting the size of each PVC.

:mag:  
**Keep in mind that each Storage Tenant (SVM) always has a root volume.  
The smallest number you can set for the maximum number of volumes is then 2.**  
:mag_right:  

**Some examples:**

1. ONTAP-NAS-ECONOMY & LimitVolumeSize = 1TB & Max Number of Volumes = 2  
You can create up to 200 PVC until you reach 1TB of capacity.  
The Kubernetes admin could update the Trident backend to grow the limit from 1TB to 2TB.

2. ONTAP-NAS-ECONOMY & LimitVolumeSize = 1TB & Max Number of Volumes = 5  
You can create up to 800 PVC (4x200) until you reach 4TB of capacity, divided in 4 ONTAP volumes.  
The storage admin could update the ONTAP parameter to create a new 1TB ONTAP volume.  

## E. What's next

You can now move on to the next section of this chapter: [What about CSI Snapshots](../5_What_about_csi_snapshots)

Or you can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp) to choose another scenario.