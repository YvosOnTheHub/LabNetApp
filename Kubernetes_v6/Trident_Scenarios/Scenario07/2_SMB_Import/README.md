#########################################################################################
# SCENARIO 7-2: Import a SMB share
#########################################################################################

**GOAL:**  
As SMB is supported by Trident, let's see how to import a share.    
A SMB Backend must already be present in order to complete this scenario. This can be achieved by following the [scenario5](../../Scenario05)

<p align="center"><img src="../Images/scenario7_2.jpg"></p>

## A. Create a volume on the storage backend

To create these 2 objects, we will use the CURL command in order to reach ONTAP REST API:  
```bash
$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "aggregates": [{"name": "aggr1"}],
  "name": "scenario7_2",
  "size": "10g",
  "style": "flexvol",
  "svm": {"name": "nassvm"}
}' "https://cluster1.demo.netapp.com/api/storage/volumes"
```

A FlexVol called **scenario7_2** has been created.  

## B. Import the volume

This can be achieved using the same _tridentctl import_ command used for NFS.  
Please note that:  
- The FlexVol does not need to be shared to be imported  
- If the FlexVol is shared, the Share name will not be modified once imported  
- If the FlexVol is not shared, Trident will create the SMB share  
- You need to enter the name of the FlexVol for the import operation  
- The FlexVol is going to be renamed once imported in order to follow the CSI specifications

```bash
$ tridentctl -n trident import volume BackendForSMB scenario7_2 -f pvc_smb_rwx_import.yaml
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-3e26eaf7-c81a-42cd-bc27-91fc423b2bd4 | 9.5 GiB | storage-class-smb | file     | 7f9d71c8-b6a9-4f1f-ac20-4b594dbf37e3 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+

$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
smb-import   Bound    pvc-3e26eaf7-c81a-42cd-bc27-91fc423b2bd4   9728Mi     RWX            storage-class-smb     <unset>                 3m9s
```

Notice that the FlexVol full name on the storage backend has changed to respect the CSI specifications:  
```bash
$ kubectl get pv $(kubectl get pvc smb-import -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
trident_pvc_3e26eaf7_c81a_42cd_bc27_91fc423b2bd4
```

Even though the name of the original PV has changed, you can still see it if you look into its annotations.  
```bash
$ kubectl describe pvc smb-import | grep importOriginalName
               trident.netapp.io/importOriginalName: scenario7_2
```

## C. Cleanup (optional)

This volume is no longer required & can be deleted from the environment.

```bash
$ kubectl delete pvc smb-import
persistentvolumeclaim "smb-import" deleted
```

## D. What's next

You can now move on to:

- [Scenario08](../../Scenario08): Consumption control  
- [Scenario09](../../Scenario09): Expanding volumes
- [Scenario10](../../Scenario10): Using Virtual Storage Pools 
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)