#########################################################################################
# SCENARIO 9: Expanding persistent volumes
#########################################################################################

**GOAL:**  
Trident supports the resizing of both File (NFS) & Block (iSCSI) PVC, depending on the Kubernetes version.  
NFS Resizing was introduced in K8S 1.11, while iSCSI resizing was introduced in K8S 1.16 (CSI).  

This scenario will guide you through both possibilities  
[1.](1_File_PVC) Expanding a File (RWX/NFS) PVC  
[2.](2_Block_PVC) Expanding a Block (RWO/iSCSI) PVC  
