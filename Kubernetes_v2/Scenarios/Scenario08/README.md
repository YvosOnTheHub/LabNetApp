#########################################################################################
# SCENARIO 8: Use the import feature of Trident
#########################################################################################

**GOAL:**  
Trident allows you to import a volume sitting in a NetApp backend into Kubernetes.  
Importing a NFS volume has been a Trident feature forever. However, importing a Block volume has been introduced with Trident 20.07.  

This scenario will guide you though both features
[1.](1_NAS_Import) Import a NFS volume (File RWX)  
[2.](2_SAN_Import) Import a iSCSI volume (Block RWO)