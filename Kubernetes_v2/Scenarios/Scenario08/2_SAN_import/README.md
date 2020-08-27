#########################################################################################
# SCENARIO 8#2: Import a Block volume
#########################################################################################

**GOAL:**  
Trident 20.07 introduced the possibility to import into Kubernetes a iSCSI LUN that exists in an ONTAP platform.  
A SAN Backend must already be present in order to complete this scenario. This can be achieved by following the [scenario6](../../Scenario06)

![Scenario8#2](../Images/scenario8_2.jpg "Scenario8#2")

## A. Create a volume & a LUN on the storage backend

To create these 2 objects, we will use the CURL command in order to reach ONTAP REST API:

```bash
$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "aggregates": [
    {
      "name": "aggr1",
      "uuid": "0dd40303-d469-4e83-86c6-2fca7838e067"
    }
  ],
  "name": "scenario8_2",
  "size": "10g",
  "style": "flexvol",
  "svm": {
    "name": "svm1",
    "uuid": "2829ebfb-4d6a-11e8-a5dc-005056b08451"
  }
}' "https://cluster1.demo.netapp.com/api/storage/volumes"

$ curl -X POST -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/luns" -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "name": "/vol/scenario8_2/lun0",
  "os_type": "linux",
  "space": {
    "size": 1073741824
  },
  "svm": {
    "name": "svm1",
    "uuid": "2829ebfb-4d6a-11e8-a5dc-005056b08451"
  }
}' "https://cluster1.demo.netapp.com/api/storage/luns"
```

A lun called **lun0** was created in the volume **scenario8_2**.  
We are now going to import this LUN into Kuberntes.

To know more about ONTAP REST API, please take a look at the following link:
https://library.netapp.com/ecmdocs/ECMLP2856304/html/index.html

## B. Import the volume

This can be achieved using the same _tridentctl import_ command used for NFS.  
Please note that:

- You need to enter the name of the volume containing the LUN & not the LUN name
- The LUN does not need to be mapped to an iGroup when importing it with Trident
- The volume hosting the LUN is going to be renamed once imported in order to follow the CSI specifications

```bash
$ tridentctl -n trident import volume SAN-default scenario8_2 -f pvc_rwo_import.yaml
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
|                   NAME                   |  SIZE   |   STORAGE CLASS   | PROTOCOL |             BACKEND UUID             | STATE  | MANAGED |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+
| pvc-92b0e330-4dd6-4de2-a6ac-9adce4538b7a | 1.0 GiB | storage-class-san | block    | f75dcd7f-b69c-4910-85ed-caec90bbccc9 | online | true    |
+------------------------------------------+---------+-------------------+----------+--------------------------------------+--------+---------+

$ kubectl get pvc
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
lun-import   Bound    pvc-92b0e330-4dd6-4de2-a6ac-9adce4538b7a   1Gi        RWO            storage-class-san   37s
```

Notice that the volume full name on the storage backend has changed to respect the CSI specifications:

```bash
$ kubectl get pv $(kubectl get pvc lun-import -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
nas1_pvc_ac9ba4b2_7dce_4241_8c8e_a4ced9cf7dcf
```

Even though the name of the original PV has changed, you can still see it if you look into its annotations.

```bash
$ kubectl describe pvc lun-import | grep importOriginalName
               trident.netapp.io/importOriginalName: scenario8_2
```

## C. Cleanup (optional)

This volume is no longer required & can be deleted from the environment.

```bash
$ kubectl delete pvc lun-import
persistentvolumeclaim "lun-import" deleted
```

## D. What's next

You can now move on to:

- [Scenario09](../../Scenario09): Consumption control  
- [Scenario10](../../Scenario10): Resize a NFS CSI PVC
- [Scenario11](../../Scenario11): Using Virtual Storage Pools 
- [Scenario12](../../Scenario12): StatefulSets & Storage consumption  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)