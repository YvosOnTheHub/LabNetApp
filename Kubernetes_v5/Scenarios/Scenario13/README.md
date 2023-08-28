#########################################################################################
# SCENARIO 13: Snapshots here & snapshots there, snapshot everywhere
#########################################################################################  

A snapshot is an IT industry wide term used to define a state of a system taken at a point in time.  
It can be used to radidly restore data, create backups, clones, etc...  

In this lab, we are going to cover 2 types of snapshots, which are actually tied together:
- [CSI Snapshots](1_CSI_Snapshots): Snapshots in Kubernetes managed in the user namespace  
- [ONTAP Snapshots](2_ONTAP_Snapshots): Snapshots taken in the storage backend & access in Kubernetes