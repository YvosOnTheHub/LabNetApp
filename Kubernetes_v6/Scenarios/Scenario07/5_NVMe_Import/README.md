#########################################################################################
# SCENARIO 7-4: Import a namespace
#########################################################################################

**GOAL:**  
As NVMe namespace are supported by Trident, let's see how to import them.    
A NVMe Backend must already be present in order to complete this scenario. This can be achieved by following the [scenario5](../../Scenario05)

<p align="center"><img src="../Images/scenario7_5.jpg"></p>

## A. Create a volume & a namespace on the storage backend

To create these 2 objects, we will use the CURL command in order to reach ONTAP REST API:  
```bash
$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "aggregates": [{"name": "aggr1"}],
  "name": "scenario7_5",
  "size": "10g",
  "style": "flexvol",
  "svm": {"name": "sansvm"}
}' "https://cluster1.demo.netapp.com/api/storage/volumes"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "location": {
    "namespace": "toimport",
    "volume": {"name": "scenario7_5"}
  },
  "os_type": "linux",
  "space": {"size": 1073741824},
  "svm": {"name": "sansvm"}
}' "https://cluster1.demo.netapp.com/api/storage/namespaces"
```

A namespace called **toimport** has been created in the FlexVol **scenario7_5**.  
We are now going to import this namespace into Kubernetes.

To know more about ONTAP REST API, please take a look at the following link:
https://library.netapp.com/ecmdocs/ECMLP2856304/html/index.html

## B. Import the volume

This can be achieved using the same _tridentctl import_ command used for NFS.  
Please note that:  
- You need to enter the name of the volume containing the namespace & not the namespace name
- The namespace does not need to be mapped to an NVMe subsystem when importing it with Trident
- The volume hosting the namespace is going to be renamed once imported in order to follow the CSI specifications

```bash
$ tridentctl -n trident import volume BackendForNVMe scenario7_4 -f pvc_rwo_import.yaml
+------------------------------------------+---------+--------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS    | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+--------------------+----------+--------------------------------------+--------+---------+
| pvc-dc695069-bb72-471f-9574-70a68ad4ce88 | 1.0 GiB | storage-class-nvme | block    | 493fef7f-8328-41d4-99f2-dea4281324a1 | online | true    |
+------------------------------------------+---------+--------------------+----------+--------------------------------------+--------+---------+

$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
nm-import    Bound    pvc-dc695069-bb72-471f-9574-70a68ad4ce88   1Gi        RWO            storage-class-nvme    <unset>                 14m
```

Notice that the FlexVol full name on the storage backend has changed to respect the CSI specifications:  
```bash
$ kubectl get pv $(kubectl get pvc nm-import -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
trident_pvc_dc695069_bb72_471f_9574_70a68ad4ce88
```

Even though the name of the original PV has changed, you can still see it if you look into its annotations.  
```bash
$ kubectl describe pvc nm-import | grep importOriginalName
               trident.netapp.io/importOriginalName: scenario7_5
```

## C. Cleanup (optional)

This volume is no longer required & can be deleted from the environment.

```bash
$ kubectl delete pvc nm-import
persistentvolumeclaim "nm-import" deleted
```

## D. What's next

You can now move on to:

- [Scenario08](../../Scenario08): Consumption control  
- [Scenario09](../../Scenario09): Expanding volumes
- [Scenario10](../../Scenario10): Using Virtual Storage Pools 
- [Scenario11](../../Scenario11): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)