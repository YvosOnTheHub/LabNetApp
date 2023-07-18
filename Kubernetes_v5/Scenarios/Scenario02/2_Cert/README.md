###############################################################
# SCENARIO 2: Backend configured with a SSL Certificate
###############################################################

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

You now need to edit the two _cert_ yaml files in this folder:

- _backend-nas-cert.yaml_ replace the parameter _clientCertificate_
- _secret-ontap-nfs-svm-cert.yaml_ replace the parameter _clientPrivateKey_.  

```bash
$ kubectl create -n trident -f secret-ontap-nfs-svm-cert.yaml
secret/ontap-nfs-svm-secret-cert created

$ kubectl create -n trident -f backend-nas-cert.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-cert created

$ kubectl create -f sc-csi-ontap-nas-cert.yaml
storageclass.storage.k8s.io/storage-class-nas-cert created
```

There you go, you can now create volumes with this backend, or check the other ways to create Trident backends:  

- [Backend with local ONTAP user](../1_Local_User): Configure a Trident Backend the traditional way  
- [Backend with AD user](../3_AD_User): Configure a Trident Backend with a AD user  
- [Scenario03](../../Scenario03): Install Prometheus & Grafana  
- [Scenario04](../../Scenario04): Deploy your first app with File storage  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)