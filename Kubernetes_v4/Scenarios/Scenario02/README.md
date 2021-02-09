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

- https://netapp-trident.readthedocs.io/en/stable-v20.10/kubernetes/deploying/operator-deploy.html#creating-a-trident-backend
- https://netapp-trident.readthedocs.io/en/stable-v20.10/kubernetes/operations/tasks/backends/index.html 

Once you have configured backend, the end user will create PVC against Storage Classes.  
A storage class contains the definition of what an app can expect in terms of storage, defined by some properties (access, media, driver ...)

For additional information, please refer to:

- https://netapp-trident.readthedocs.io/en/stable-v20.10/kubernetes/concepts/objects.html#kubernetes-storageclass-objects

Also, installing & configuring Trident + creating Kubernetes Storage Classe is what is expected to be done by the Admin.

<p align="center"><img src="Images/scenario2.jpg"></p>

## A. Create your first NFS backends

You will find in this directory a few backends files.  
You can decide to use all of them, only a subset of them or modify them as you wish

Here are the 2 backends & their corresponding driver:

- backend-nas-default.json        ONTAP-NAS
- backend-nas-eco-default.json    ONTAP-NAS-ECONOMY

```bash
$ tridentctl -n trident create backend -f backend-nas-default.json
+-----------------+----------------+--------------------------------------+--------+---------+
|      NAME       | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+-----------------+----------------+--------------------------------------+--------+---------+
| NAS_Vol-default | ontap-nas      | 282b09e5-0ff2-4471-97c8-9fd5224945a1 | online |       0 |
+-----------------+----------------+--------------------------------------+--------+---------+

$ tridentctl -n trident create backend -f backend-nas-eco-default.json
+-----------------+-------------------+--------------------------------------+--------+---------+
|      NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+-----------------+-------------------+--------------------------------------+--------+---------+
| NAS_ECO-default | ontap-nas-economy | b21fb2a7-975a-4050-a187-bb4f883d0e97 | online |       0 |
+-----------------+-------------------+--------------------------------------+--------+---------+

$ kubectl get -n trident tridentbackends
NAME        BACKEND           BACKEND UUID
tbe-c874k   NAS_Vol-default   282b09e5-0ff2-4471-97c8-9fd5224945a1
tbe-d6szt   NAS_ECO-default   b21fb2a7-975a-4050-a187-bb4f883d0e97
```

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

First, we need to create a public key (.pem file) & a private key (a .key file) on the host that own tridentctl.  
As this will be used against a SVM, I need specify a SVM user that will correspond to this certificate (ex: _vsadmin_)

```bash
openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -keyout k8senv.key -out k8senv.pem -subj "/C=US/ST=NC/L=RTP/O=NetApp/CN=vsadmin"
```

The next steps are done with the ONTAP CLI (enable authentication & certificate copy/paste).  

```bash
$ security ssl modify -vserver nfs_svm -client-enabled true
$ security cert install -type client-ca -cert-name vsadmin_trident -vserver nfs_svm
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
Keep in mind that these certicates will be used in an encoded format by Trident:

```bash
base64 -w 0 k8senv.pem >> cert_base64
base64 -w 0 k8senv.key >> key_base64
```

You now need to edit the _backend-nas-cert.json_ file & replace the 2 parameters: _clientCertificate_ & _clientPrivateKey_.  

```bash
$ kubectl create -f sc-csi-ontap-nas-cert.yaml
storageclass.storage.k8s.io/storage-class-nas-cert created

$ tridentctl -n trident create backend -f backend-nas-cert.json
+-----------------+----------------+--------------------------------------+--------+---------+
|      NAME       | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+-----------------+----------------+--------------------------------------+--------+---------+
| NAS_Cert        | ontap-nas      | 9f6d53b4-7102-4f86-900d-5a76e3665903 | online |       0 |
+-----------------+----------------+--------------------------------------+--------+---------+
```

There you go, you can now create volumes with this backend.

## D. What's next

Now, you have some NAS Backends & some storage classes configured. You can proceed to the creation of a stateful application:  

- [Scenario03](../Scenario03): Install Prometheus & Grafana  
- [Scenario04](../Scenario04): Deploy your first app with File storage  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)