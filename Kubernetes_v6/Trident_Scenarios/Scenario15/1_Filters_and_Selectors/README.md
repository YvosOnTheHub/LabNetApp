#########################################################################################
# SCENARIO 15: Filters and Selectors
#########################################################################################

Most storage classes are configured with simple parameters, for instance: 
- _backendType_ (example "ontap-nas")  
- _media_ (example: "ssd")  
- _snapshots_ (example: "true")  

This already allows you to filter on a subset of Trident backends.  
However, this is not always enough. Let's see some additional configuration elements.  

## A. StoragePools

The storage class _storagePools_ parameter can be defined to explicitly list all the Trident backends that can be used.  
Each item of that parameter is defined in the following manner: **BackendName:aggregates**.  
A wildcard (".*") can be used to specify that you want to use all existing _aggregates_.  

Let's create some backends and a storage class with the _storagepools.yaml_ file you can find in this folder:  
```bash
$ kubectl create -f storagepools.yaml
secret/sc15-sp created
tridentbackendconfig.trident.netapp.io/sc15-sp-tbc1 created
tridentbackendconfig.trident.netapp.io/sc15-sp-tbc2 created
storageclass.storage.k8s.io/sc15-sp created
```
For the time being, the storage class contains the parameter _storagePools: "Sc15SpTBC1:.*"_ which points to the first backend.  
Let's check with _tridentctl_ all pools available for that storage class:  
```bash
$ tridentctl -n trident get storageclass sc15-sp -o json | jq  '[.items[] | {storageClass: .Config.name, backends: [.storage]|unique}]'| jq .[0]
{
  "storageClass": "sc15",
  "backends": [
    {
      "Sc15SpTBC1": [
        "aggr1",
        "aggr2"
      ]
    }
  ]
}
```
Now, you would like to add a second backend to that storage class. How would you proceed ?  
The _parameters_ category of a storage is immutable.  
If you tried to edit the storage class to manually add a backend, you would get the following error:  
```yaml
# storageclasses.storage.k8s.io "sc15" was not valid:
# * parameters: Forbidden: updates to parameters are forbidden.
```

In order to get the desired outcome, you need to recreate the storage class.  
You can safely delete the existing storage class, as corresponding workloads will not be impacted.  
But make sure to reuse the same name when recreating the storge class.  
```bash
$ kubectl delete sc sc15-sp
storageclass.storage.k8s.io "sc15-sp" deleted

$ cat << EOF | kubectl apply  -f - 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc15-sp
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  storagePools: "Sc15SpTBC1:.*;Sc15SpTBC2:aggr2"
allowVolumeExpansion: true
EOF
storageclass.storage.k8s.io/sc15 created
```
Let's check the result:  
```bash
$ tridentctl -n trident get storageclass sc15-sp -o json | jq  '[.items[] | {storageClass: .Config.name, backends: [.storage]|unique}]'| jq .[0]
{
  "storageClass": "sc15",
  "backends": [
    {
      "Sc15SpTBC1": [
        "aggr1",
        "aggr2"
      ],
      "Sc15SpTBC2": [
        "aggr2"
      ]
    }
  ]
}
```
This time, you have access to both backends.  
Note that I explicitly set a specific aggregate for the second backend for this exercise.  

The _StoragePools_ parameter is great if used in all storage classes.  
Otherwise, you may end up with volumes created on a backend you don't want to use.  

This lab already contains a sc called _storage-class-nfs_ which does not have this parameter set. It only contains the filters _backendType: "ontap-nas"_ and _nasType: "nfs"_ which are also valid here.  
You can see that it also points to the 2 backends created in this scenario:  
```bash
$ tridentctl -n trident get storageclass storage-class-nfs -o json | jq  '[.items[] | {storageClass: .Config.name, backends: [.storage]|unique}]'| jq .[0]
{
  "storageClass": "storage-class-nfs",
  "backends": [
    {
      "BackendForNFS": [
        "aggr1",
        "aggr2"
      ],
      "Sc15SpTBC1": [
        "aggr1",
        "aggr2"
      ],
      "Sc15SpTBC2": [
        "aggr1",
        "aggr2"
      ]
    }
  ]
}
```

Let's clean up these objects before proceeding with the next paragraph:  
```bash
$ kubectl delete -f storagepools.yaml
secret/sc15-sp deleted
tridentbackendconfig.trident.netapp.io/sc15-sp-tbc1 deleted
tridentbackendconfig.trident.netapp.io/sc15-sp-tbc2 deleted
storageclass.storage.k8s.io/sc15-sp deleted
```

## B. Selectors

An alternative to storage pools would be to use labels defined in Trident backends.  
This is often used when configuring Virtual Storage Pools, which are covered in the [Scenario10](../../Scenario10/).  
We can also use that method to group different backends altogether.  

Let's create a new set of objects, with the file _selectors.yaml_:  
```bash
$ kubectl create -f selectors.yaml
secret/sc15-selector created
tridentbackendconfig.trident.netapp.io/sc15-sel-tbc1 created
tridentbackendconfig.trident.netapp.io/sc15-sel-tbc2 created
storageclass.storage.k8s.io/sc15-selector created
```
Note that a label _scenario: sc15_ is only positioned on the first backend.  
Let's check the result:  
```bash
$ tridentctl -n trident get storageclass sc15-selector -o json | jq  '[.items[] | {storageClass: .Config.name, backends: [.storage]|unique}]'| jq .[0]
{
  "storageClass": "sc15-selector",
  "backends": [
    {
      "Sc15SelTBC1": [
        "aggr1",
        "aggr2"
      ]
    }
  ]
}
```
Now, you would like to link a new backend to the same storage class.  
Let's try to patch this resource to add the _labels_ field:  
```bash
$ kubectl -n trident patch tridentbackendconfig sc15-sel-tbc2 --type='merge' -p '{"spec":{"labels":{"scenario":"sc15"}}}'
tridentbackendconfig.trident.netapp.io/sc15-sel-tbc2 patched
```
Let's see the result:
```bash
$ tridentctl -n trident get storageclass sc15-selector -o json | jq  '[.items[] | {storageClass: .Config.name, backends: [.storage]|unique}]'| jq .[0]
{
  "storageClass": "sc15-selector",
  "backends": [
    {
      "Sc15SelTBC1": [
        "aggr1",
        "aggr2"
      ],
      "Sc15SelTBC2": [
        "aggr1",
        "aggr2"
      ]
    }
  ]
}
```
As you can witness, both backends are now linked to the same storage class, without modifying the storage class definition.  
However, the same remark applies here. If you had such filter, all backends and storage classes must follow the same logic.  
Here again, if you check on the default NAS storage class, you will find the 2 new Trident backends:  
```bash
$ tridentctl -n trident get storageclass storage-class-nfs -o json | jq  '[.items[] | {storageClass: .Config.name, backends: [.storage]|unique}]'| jq .[0]
{
  "storageClass": "storage-class-nfs",
  "backends": [
    {
      "BackendForNFS": [
        "aggr1",
        "aggr2"
      ],
      "Sc15SelTBC1": [
        "aggr1",
        "aggr2"
      ],
      "Sc15SelTBC2": [
        "aggr1",
        "aggr2"
      ]
    }
  ]
}
```

Last, note that these is no way to specify a list of aggregates in this case.  
You could use the backend _aggregate_ parameter to narrow down the pool, but this field only takes one value (ie, one aggregate).

Let's finish that scenario with some cleanup:
```bash
$ kubectl delete -f selectors.yaml
secret/sc15-selector deleted
tridentbackendconfig.trident.netapp.io/sc15-sel-tbc1 deleted
tridentbackendconfig.trident.netapp.io/sc15-sel-tbc2 deleted
storageclass.storage.k8s.io/sc15-selector deleted
```