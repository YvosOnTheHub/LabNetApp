#########################################################################################
# SCENARIO 7: Importing data with Trident
#########################################################################################

**GOAL:**  
Trident allows you to import a volume sitting in a NetApp backend into Kubernetes.  
Importing a NFS volume has been a Trident feature forever. However, importing a Block volume has been introduced with Trident 20.07.  

Trident 23.07 introduced a new feature that permits users to import specific snapshots into Kubernetes.  
This chapter will also cover this use case.  

This scenario will guide you through both features  
[1.](1_NAS_Import) Import a NFS volume  
[2.](2_Snapshot_Import) Import a snapshot  
[3.](3_SAN_Import) Import a iSCSI volume  
