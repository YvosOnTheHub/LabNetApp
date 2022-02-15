#########################################################################################
# SCENARIO 2: Create your first NFS backends for Trident & Storage Classes for Kubernetes
#########################################################################################

**GOAL:**  
Trident needs to know where to create volumes.  
This information sits in objects called backends. It basically contains:

- the driver type (there currently are 10 different drivers available)
- how to connect to the driver (IP, login, password ...)
- some default parameters

For additional information, please refer to:

- https://netapp-trident.readthedocs.io/en/stable-v21.04/kubernetes/deploying/operator-deploy.html#creating-a-trident-backend
- https://netapp-trident.readthedocs.io/en/stable-v21.04/kubernetes/operations/tasks/backends/index.html 

Once you have configured backend, the end user will create PVC against Storage Classes.  
A storage class contains the definition of what an app can expect in terms of storage, defined by some properties (access, media, driver ...)

For additional information, please refer to:

- https://netapp-trident.readthedocs.io/en/stable-v21.04/kubernetes/concepts/objects.html#kubernetes-storageclass-objects

Also, installing & configuring Trident + creating Kubernetes Storage Classe is what is expected to be done by the Admin.  

Trident 21.04 introduced the possibility to manage Trident backends directly with _kubectl_, whereas it was previously solely feasible with _tridentctl_.  
Managing backends this way is done with 2 different objects:

- **Secrets** which contain the credentials necessary to connect to the storage (login/pwd or certificate)
- **TridentBackendConfig** which is a new CRD that contains all the parameters related to this backend.

Note that _secrets_ can be used by multiple _TridentBackendConfigs_.

<p align="center"><img src="Images/scenario2.jpg"></p>

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

Here are the 2 backends & their corresponding driver, both using the secret stored in the file _secret_ontap_nfs-svm.yaml_:

- backend_nas-default.yaml        ONTAP-NAS
- backend_nas-eco-default.yaml    ONTAP-NAS-ECONOMY

```bash
$ kubectl create -n trident -f secret_ontap_nfs-svm_username.yaml
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

## C. What about authentication through certificates ?

Trident 21.01 introduced the possibility to configure Trident backends with SSL certificates, instead of traditional user/password methods.  
We will see here how to easily enable this feature.  

First, we need to create a public key (.pem file) & a private key (a .key file) on the host that owns tridentctl.  
As this will be used against a SVM, I need specify a SVM user that will correspond to this certificate (ex: _vsadmin_)

```bash
openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -keyout k8senv.key -out k8senv.pem -subj "/C=US/ST=NC/L=RTP/O=NetApp/CN=vsadmin"
```

The next steps are done with the ONTAP CLI (enable authentication & certificate copy/paste).  
For the first command, use the content of the k8senv.pem file.  

```bash
$ security cert install -type client-ca -cert-name vsadmin_trident -vserver nfs_svm
$ security ssl modify -vserver nfs_svm -client-enabled true
$ security cert show -vserver nfs_svm -type client-ca
  (security certificate show)
Vserver    Serial Number   Certificate Name                       Type
---------- --------------- -------------------------------------- ------------
nfs_svm    8C7EA27B56FD230F
                           vsadmin_trident                         client-ca
    Certificate Authority: vsadmin
          Expiration Date: Mon Feb 05 14:08:43 2024
```

Last, we need to enable certification authentication with the login role we will use (vsadmin)

```bash
$ security login create -user-or-group-name vsadmin -application ontapi -authentication-method cert -vserver nfs_svm
$ security login create -user-or-group-name vsadmin -application http -authentication-method cert -vserver nfs_svm
$ security login show -vserver nfs_svm -authentication-method cert
  
Vserver: nfs_svm
                                                                 Second
User/Group                 Authentication                 Acct   Authentication
Name           Application Method        Role Name        Locked Method
-------------- ----------- ------------- ---------------- ------ --------------
vsadmin        http        cert          vsadmin          -      none
vsadmin        ontapi      cert          vsadmin          -      none
2 entries were displayed.
```

Back to the Kubernetes host, we can now proceed with the backend creation.  
Keep in mind that these certificates will be used in an encoded format by Trident:

```bash
base64 -w 0 k8senv.pem >> cert_base64
base64 -w 0 k8senv.key >> key_base64
```

You now need to edit the _backend-nas-cert.json_ file & replace the 2 parameters: _clientCertificate_ & _clientPrivateKey_.  

```bash
$ tridenct create -n trident -f backend-nas-cert.json
+-----------------+-------------------+--------------------------------------+--------+---------+
|      NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+-----------------+-------------------+--------------------------------------+--------+---------+
| NAS_Cert        | ontap-nas         | 9f6d53b4-7102-4f86-900d-5a76e3665903 | online |       0 |
+-----------------+-------------------+--------------------------------------+--------+---------+

$ kubectl create -f sc-csi-ontap-nas-cert.yaml
storageclass.storage.k8s.io/storage-class-nas-cert created
```

There you go, you can now create volumes with this backend.

## D. What's next

Now, you have some NAS Backends & some storage classes configured. You can proceed to the creation of a stateful application:  

- [Scenario03](../Scenario03): Install Prometheus & Grafana  
- [Scenario04](../Scenario04): Deploy your first app with File storage  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)