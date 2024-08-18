#########################################################################################
# SCENARIO 7-3: Import a Block volume
#########################################################################################

**GOAL:**  
Trident 20.07 introduced the possibility to import into Kubernetes a iSCSI LUN that exists in an ONTAP platform.  
An iSCSI Backend must already be present in order to complete this scenario. This can be achieved by following the [scenario5](../../Scenario05)

<p align="center"><img src="../Images/scenario7_4.jpg"></p>

## A. Create a volume & a LUN on the storage backend

To create these 2 objects, we will use the CURL command in order to reach ONTAP REST API:  
```bash
$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "aggregates": [{"name": "aggr1"}],
  "name": "scenario7_4",
  "size": "10g",
  "style": "flexvol",
  "svm": {"name": "sansvm"}
}' "https://cluster1.demo.netapp.com/api/storage/volumes"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "name": "/vol/scenario7_4/lun0",
  "os_type": "linux",
  "space": {"size": 1073741824},
  "svm": {"name": "sansvm"}
}' "https://cluster1.demo.netapp.com/api/storage/luns"
```

A lun called **lun0** has been created in the FlexVol **scenario7_4**.  
We are now going to import this LUN into Kubernetes.

To know more about ONTAP REST API, please take a look at the following link:
https://library.netapp.com/ecmdocs/ECMLP2856304/html/index.html

## B. Import the volume

This can be achieved using the same _tridentctl import_ command used for NFS.  
Please note that:  
- You need to enter the name of the volume containing the LUN & not the LUN name
- The LUN does not need to be mapped to an iGroup when importing it with Trident
- The volume hosting the LUN is going to be renamed once imported in order to follow the CSI specifications

```bash
$ tridentctl -n trident import volume BackendForiSCSI scenario7_4 -f pvc_rwo_import.yaml
+------------------------------------------+---------+---------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |    STORAGE CLASS    | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+---------------------+----------+--------------------------------------+--------+---------+
| pvc-6b41338d-0c82-407a-9396-d9e99478a573 | 1.0 GiB | storage-class-iscsi | block    | 17c482e4-6aa7-4a0a-b4f8-26c75eae8a59 | online | true    |
+------------------------------------------+---------+---------------------+----------+--------------------------------------+--------+---------+

$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
lun-import   Bound    pvc-6b41338d-0c82-407a-9396-d9e99478a573   1Gi        RWO            storage-class-iscsi   <unset>                 14s
```

Notice that the FlexVol full name on the storage backend has changed to respect the CSI specifications:  
```bash
$ kubectl get pv $(kubectl get pvc lun-import -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
trident_pvc_6b41338d_0c82_407a_9396_d9e99478a573
```

Even though the name of the original PV has changed, you can still see it if you look into its annotations.  
```bash
$ kubectl describe pvc lun-import | grep importOriginalName
               trident.netapp.io/importOriginalName: scenario7_4
```

## C. Cleanup (optional)

This volume is no longer required & can be deleted from the environment.

```bash
$ kubectl delete pvc lun-import
persistentvolumeclaim "lun-import" deleted
```

## D. What's next

You can now move on to:

- [Scenario08](../../Scenario08): Consumption control  
- [Scenario09](../../Scenario09): Expanding volumes
- [Scenario10](../../Scenario10): Using Virtual Storage Pools 
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)