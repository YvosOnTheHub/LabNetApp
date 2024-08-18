#########################################################################################
# SCENARIO 9: Expanding persistent volumes
#########################################################################################

**GOAL:**  
Trident supports the resizing of both File (NFS & SMB) & Block (iSCSI & NVMe) PVC, depending on the Kubernetes version.  
NFS Resizing was introduced in K8S 1.11, while iSCSI resizing was introduced in K8S 1.16 (CSI).  

Resizing a PVC is possible when the parameter _allowVolumeExpansion: true_ is set in the storage class.  
All 4 storage classes already have this feature enabled, so no need to create new storage classes or new backends.  
```bash
$ kubectl get sc
NAME                  PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
storage-class-iscsi   csi.trident.netapp.io   Delete          Immediate           true                   87d
storage-class-nfs     csi.trident.netapp.io   Delete          Immediate           true                   87d
storage-class-nvme    csi.trident.netapp.io   Delete          Immediate           true                   87d
storage-class-smb     csi.trident.netapp.io   Delete          Immediate           true                   87d
```
Notice the fifth column?  

This scenario will guide you through examples with each protocol:    
[1.](1_NFS) Expanding a NFS PVC  
2. Expanding a SMB PVC (**_Work in progress_**)  
[3.](3_iSCSI) Expanding an iSCSI PVC  
[4.](4_NVMe) Expanding a NVMe PVC  