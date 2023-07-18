###############################################################
# SCENARIO 2: Backend configured with a local ONTAP user
###############################################################

## A. Create your first NFS backends

You will find in this directory a few backends YAML files, as well as secrets.  
You can decide to use all of them, only a subset of them or modify them as you wish

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>  

The backend files contain the parameter _snapshotDir: 'true'_ which makes the .snapshot folders visible inside the POD.
This works perfectly well with this Lab on Demand environment (Centos7). However, if you plan on using it on your own infrastructure or in another lab (Centos8+), you may get the following error when creating an app:

```bash
kubectl logs -n ghost1  blog-bc476b85c-ts9td
chown: /var/lib/ghost/content/.snapshot: Read-only file system
```

You can then simply edit the backend file & remove this parameter, which will resolve the situation

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>  

Here are the 2 backends & their corresponding driver, both using the secret stored in the file _secret_ontap_nfs-svm_username.yaml_:

- backend_nas-default.yaml        ONTAP-NAS
- backend_nas-eco-default.yaml    ONTAP-NAS-ECONOMY

```bash
$ kubectl create -n trident -f secret-ontap-nfs-svm-username.yaml
secret/ontap-nfs-svm-secret-username created

$ kubectl create -n trident -f backend-nas-default.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-default created

$ kubectl create -n trident -f backend-nas-eco-default.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-eco-default created

$ kubectl get tbc -n trident
NAME                                                                       BACKEND NAME      BACKEND UUID                           PHASE   STATUS
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-default       nas-default       1efa694f-039f-44ab-a62a-30d55c2384f5   Bound   Success
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-eco-default   nas-eco-default   ee9458a3-b91e-4bfb-bb3b-e92c6049b44a   Bound   Success

$ kubectl get tbe -n trident
NAME                                         BACKEND           BACKEND UUID
tridentbackend.trident.netapp.io/tbe-cbppg   nas-default       1efa694f-039f-44ab-a62a-30d55c2384f5
tridentbackend.trident.netapp.io/tbe-mmr2j   nas-eco-default   ee9458a3-b91e-4bfb-bb3b-e92c6049b44a

$ tridentctl -n trident get backend
+-----------------+-------------------+--------------------------------------+--------+---------+
|      NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+-----------------+-------------------+--------------------------------------+--------+---------+
| nas-eco-default | ontap-nas-economy | ee9458a3-b91e-4bfb-bb3b-e92c6049b44a | online |       0 |
| nas-default     | ontap-nas         | 1efa694f-039f-44ab-a62a-30d55c2384f5 | online |       0 |
+-----------------+-------------------+--------------------------------------+--------+---------+
```

A few things to notice:

- even though the backends were created with _kubectl_, you can see them with _tridentctl_
- all backend modifications must be applied to the _trident backend config_ objects, not the _trident backend_ ones.

## B. Create storage classes pointing to each backend

You will also find in this directory a few storage class files.
You can decide to use all of them, only a subset of them or modify them as you wish.

Note that the storage class **storage-class-nas** is set to be the **default** one.

```bash
$ kubectl create -f sc-csi-ontap-nas.yaml
storageclass.storage.k8s.io/storage-class-nas created

$ kubectl create -f sc-csi-ontap-nas-eco.yaml
storageclass.storage.k8s.io/storage-class-nas-economy created

$ kubectl get sc
NAME                          PROVISIONER             AGE
storage-class-nas (default)   csi.trident.netapp.io   2d18h
storage-class-nas-economy     csi.trident.netapp.io   2d18h
```

At this point, end-users can now create PVC against one of theses storage classes.  

Now, you have some NAS Backends & some storage classes configured. You can proceed to the creation of a stateful application, or check the other ways to create Trident backends:  

- [Backend with certificate](../2_Cert): Configure a Trident Backend with a SSL certificate  
- [Backend with AD user](../3_AD_User): Configure a Trident Backend  
- [Scenario03](../../Scenario03): Install Prometheus & Grafana  
- [Scenario04](../../Scenario04): Deploy your first app with File storage  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)