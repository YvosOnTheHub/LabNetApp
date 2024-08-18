#########################################################################################
# SCENARIO 23: Naming conventions
#########################################################################################

Until recently, when a volume was created by Trident, it would look like _trident_pvc_e018e7ab_a95b_4cb7_a366_85953d8fdec5_ on the storage backend.  
Not necesarily an issue, unless you would like to know which application mounts what volume when looking at the storage.  
For that, 2 solutions:  
- maintain a database  
- have a very good memory  

Obviously, not very user friendly.  

Trident 24.06 introduced volume naming customization, as well as label customization.  
Let's see them in action.  

## A. Volume Name Customization

This is done with the _nameTemplate_ backend parameter. Here is an example:  
```yaml
nameTemplate: {{ .config.StoragePrefix }}_{{ .volume.Name }}_{{ .volume.BackendName }}
```

Let's create a backend, a PVC and see the result.  
```bash
$ kubectl create -f config_nameTemplate.yaml
secret/secret-nametemplate created
tridentbackendconfig.trident.netapp.io/tbc-nametemplate created
storageclass.storage.k8s.io/sc-nametemplate created
namespace/nametemplate created
persistentvolumeclaim/pvc1 created
```
Note that Trident automatically adds a suffix corresponding to a slice of the volume name (ie its UUID):  
```bash
$ kubectl get -n trident tbc tbc-nametemplate -o jsonpath={".spec.defaults.nameTemplate"}; echo
{{ .config.StoragePrefix }}_{{ .volume.Namespace }}_{{ .volume.RequestName }}

$ kubectl get tbe -n trident tbe-pw62b
NAME        BACKEND        BACKEND UUID
tbe-pw62b   nametemplate   2ddfd6b3-a6b6-4c19-af99-847791c9daba

$ kubeclt get tbe -n trident tbe-pw62b -o jsonpath={".config.ontap_config.defaults.nameTemplate"};echo
{{ .config.StoragePrefix }}_{{ .volume.Namespace }}_{{ .volume.RequestName }}_{{slice .volume.Name 4 9}}
```
What about our volume:  
```bash
$ kubectl get pvc,pv -n nametemplate
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/pvc1   Bound    pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28   5Gi        RWX            sc-nametemplate    <unset>                 158m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28   5Gi        RWX            Delete           Bound    nametemplate/pvc1    sc-nametemplate    <unset>                          158m
```
Let's retrieve this PVC name in ONTAP:  
```bash
$ kubectl get pv pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28 -o jsonpath={".spec.csi.volumeAttributes.internalName"}; echo
lod_nametemplate_pvc1_aa1f4
```
It is indeed a bit easier to read & understand.  
Quick check on each part of the template:  
```bash
$ kubeclt get tbe -n trident tbe-pw62b -o jsonpath={".config.ontap_config.defaults.nameTemplate"};echo
{{ .config.StoragePrefix }}_{{ .volume.Namespace }}_{{ .volume.RequestName }}_{{slice .volume.Name 4 9}}

$ kubectl get tbe -n trident tbe-pw62b -o jsonpath={".config.ontap_config.storagePrefix"};echo
lod
$ kubectl get tvol -n trident pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28 -o jsonpath={".config.namespace"};echo
nametemplate
$ kubectl get tvol -n trident pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28 -o jsonpath={".config.requestName"};echo
pvc1
$ kubectl get tvol -n trident pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28 -o jsonpath={".config.name"};echo
pvc-aa1f4d54-b522-4310-9dc7-ac6265886b28
```
Now, you understand how the name is built.  
Note that if you manually add the _slice .volume.Name_ to the backend configuration, Trident does not add another iteration of that element.  

## B. Volume Label Customization  

You have had the possibility to add labels for a while, but those were static, ie all the volumes created through a backend would have the same labels. You can now also customize those labels, following the same logic as the name template.  

In the scenario example, I will use the following template:
```yaml  
labels: {"cluster": "LoD", "Namespace": "{{.volume.Namespace}}", "PVC": "{{.volume.RequestName}}"}
```

Let's create a backend, a PVC and see the result.  
```bash
$ kubectl create -f config_labelTemplate.yaml
secret/secret-labeltemplate created
tridentbackendconfig.trident.netapp.io/tbc-labeltemplate created
storageclass.storage.k8s.io/sc-labeltemplate created
namespace/labeltemplate created
persistentvolumeclaim/pvc1 created
```

We first need to retrieve the name of the volume created by Trident in the ONTAP system.
Then we can either use System Manager, the ONTAP CLI or API to retrieve the _comment_ field of this volume:  
```bash
$ kubectl get pv $( kubectl -n labeltemplate get pvc pvc1 -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}';echo
lod_pvc_989be5cc_88a5_4ace_a7b5_c5d66ee38649

$ curl -s -X GET -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/volumes?name=lod_pvc_989be5cc_88a5_4ace_a7b5_c5d66ee38649&fields=comment" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "6a4be7fa-558e-11ef-84c0-005056b0e2f3",
      "comment": "{\"provisioning\":{\"Namespace\":\"labeltemplate\",\"PVC\":\"pvc1\",\"cluster\":\"LoD\"}}",
      "name": "lod_pvc_989be5cc_88a5_4ace_a7b5_c5d66ee38649"
    }
  ],
  "num_records": 1
}
```

Tadaaa, you can see both the **dynamic** labels (_pvc1_ & _labeltemplate_) and **static** label (_LoD_) in the comment field!


## Cleanup & Next

```bash
kubectl delete -f config_nameTemplate.yaml
kubectl create -f config_labelTemplate.yaml
```

You can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)