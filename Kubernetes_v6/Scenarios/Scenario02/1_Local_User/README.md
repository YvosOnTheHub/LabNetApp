###############################################################
# SCENARIO 2: Backend configured with a local ONTAP user
###############################################################

This lab already has 2 backends configured to provide NFS & SMB volumes with the ONTAP-NAS driver.  
As they have been created with the _tridentctl_ tool, there is no TBC (TridentBackendConfig) object associated with them that allow backend management with kubectl. We will then first go through the creation of the 2 TBC.  
Then, we will also create a ONTAP-NAS-ECONOMY backend which will then create qtrees in ONTAP.  

## A. Create the TBC objects corresponding to the existing NAS backends

```bash
$ tridentctl -n trident get backend
+-----------------+----------------+--------------------------------------+--------+------------+---------+
|      NAME       | STORAGE DRIVER |                 UUID                 | STATE  | USER-STATE | VOLUMES |
+-----------------+----------------+--------------------------------------+--------+------------+---------+
| BackendForNFS   | ontap-nas      | 11d28fb4-6cf5-4c59-931d-94b8d8a5e061 | online | normal     |       0 |
| BackendForSMB   | ontap-nas      | 7f9d71c8-b6a9-4f1f-ac20-4b594dbf37e3 | online | normal     |       0 |
| BackendForNVMe  | ontap-san      | 493fef7f-8328-41d4-99f2-dea4281324a1 | online | normal     |       0 |
| BackendForiSCSI | ontap-san      | 17c482e4-6aa7-4a0a-b4f8-26c75eae8a59 | online | normal     |       0 |
+-----------------+----------------+--------------------------------------+--------+------------+---------+
```
Moving from a tridentctl based backend to a kubectl one requires the creation of 2 objects:  
- a secret
- a TBC
When going through that process, make sure that the backend parameters are correctly reported in the TBC.  

This folder already contains the necesary files:
```bash
$ kubectl create -f secret-ontap-nas-svm-creds.yaml
secret/secret-nas-svm-creds created
$ kubectl create -f backend-tbc-nfs.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-nfs created
$ kubectl create -f backend-tbc-smb.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-smb created
```

Let's check that it all went fine. Backends should be displayed as "status=success" & no new entry should be visible when listing the backends with tridentctl.  
```bash
$ kubectl get tbc -A
NAMESPACE   NAME              BACKEND NAME    BACKEND UUID                           PHASE   STATUS
trident     backend-tbc-nfs   BackendForNFS   11d28fb4-6cf5-4c59-931d-94b8d8a5e061   Bound   Success
trident     backend-tbc-smb   BackendForSMB   7f9d71c8-b6a9-4f1f-ac20-4b594dbf37e3   Bound   Success

$ tridentctl -n trident get backend
+-----------------+----------------+--------------------------------------+--------+------------+---------+
|      NAME       | STORAGE DRIVER |                 UUID                 | STATE  | USER-STATE | VOLUMES |
+-----------------+----------------+--------------------------------------+--------+------------+---------+
| BackendForNFS   | ontap-nas      | 11d28fb4-6cf5-4c59-931d-94b8d8a5e061 | online | normal     |       0 |
| BackendForSMB   | ontap-nas      | 7f9d71c8-b6a9-4f1f-ac20-4b594dbf37e3 | online | normal     |       0 |
| BackendForNVMe  | ontap-san      | 493fef7f-8328-41d4-99f2-dea4281324a1 | online | normal     |       0 |
| BackendForiSCSI | ontap-san      | 17c482e4-6aa7-4a0a-b4f8-26c75eae8a59 | online | normal     |       0 |
+-----------------+----------------+--------------------------------------+--------+------------+---------+
```
All good !

Note that all backend modifications must be applied to the _trident backend config_ objects, not the _trident backend_ ones.  

The storage classes are already present, so no need to recreate or modify them.  
```bash
$ kubectl get sc
NAME                  PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storage-class-iscsi   csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-nfs     csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-nvme    csi.trident.netapp.io   Delete          Immediate           true                   75d
storage-class-smb     csi.trident.netapp.io   Delete          Immediate           true                   75d
```

## B. SMB Storage class specificities  

If you take a closer look at the SMB storage class, you will notice those 2 lines:  
```yaml
  csi.storage.k8s.io/node-stage-secret-name: "smbcreds"
  csi.storage.k8s.io/node-stage-secret-namespace: ${pvc.namespace}
```
When using SMB, the POD will use Active Directory credentials to mount the volume.  
The two highlighted parameters are here to specify where to look for those credentials, as well as the name of the secret containing them.  
_pvc.namespace_ means that we are looking for the secret object in the same namespace as the PVC. 

## C. Create a ONTAP-NAS-ECONOMY environment

Using the ONTAP-NAS driver provides you the full potential of Trident.  
In this context, a NAS PVC will correspond to an ONTAP FlexVol.  
Everything has limits, and specifically with ONTAP you can host up to 2500 FlexVol per controller (that depends on various parameters, such as version or architecture. Check hwu.netapp.com for correct values).  

If that limit is too low, one alternative is to move to the ONTAP-NAS-ECONOMY Trident driver, which will then create ONTAP _qtrees_ (see them as FlexVol subfolders). Trident allow you to create up to 300 qtree for FlexVol. If you do the math, you can host up to 2500x300 PVC on one ONTAP controller, which is great !  

Important to note that:  
- **CSI snapshots are not supported with ONTAP-NAS-ECONOMY**  
- Import is not supported with ONTAP-NAS-ECONOMY  

The TBC we are going to create uses the same _secret_ created in the first part of this chapter.  
We also need a new storage class to complete the process.  
```bash
$ kubectl create -f backend-nas-eco.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nfs-qtrees created
$ kubectl create -f sc-nfs-ontap-nas-eco.yaml
storageclass.storage.k8s.io/storage-class-nas-economy created

$ kubectl get -n trident tbc backend-tbc-nfs-qtrees
NAME                     BACKEND NAME          BACKEND UUID                           PHASE   STATUS
backend-tbc-nfs-qtrees   BackendForNFSQtrees   bd3b79ae-c929-4151-9bc2-c636c9289da6   Bound   Success
```

At this point, end-users can now create PVC against one of those storage classes.  

Now, you have some NAS Backends & some storage classes configured. You can proceed to the creation of a stateful application, or check the other ways to create Trident backends:  

- [Backend with certificate](../2_Cert): Configure a Trident Backend with a SSL certificate  
- [Backend with AD user](../3_AD_User): Configure a Trident Backend  
- [Scenario03](../../Scenario03): Install Prometheus & Grafana  
- [Scenario04](../../Scenario04): Deploy your first app with File storage  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)