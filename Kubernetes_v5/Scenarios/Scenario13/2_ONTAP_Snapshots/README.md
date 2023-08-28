#########################################################################################
# SCENARIO 13: ONTAP Snapshots
#########################################################################################  

ONTAP Snapshots are part of NetApp's Data Protection catalog of features.  
They are read-only, point-in-time images of volumes, based on metadata, which makes them fast, efficient and reliable.  

In the context of Kubernetes:
- Snapshots can be made accessible in a POD
- Snapshots can be made visible in a POD
- ONTAP Snapshots are the objects created by Trident upon CSI Snapshots creation

In the context of Trident, here are the parameters that can be set in a backend that work alongside snapshots:
- **snapshotPolicy** (default: _none_): specifies the name of the snapshot policy associated to a volume. This policy must be present in the SVM  
- **snapshotReserve**: percentage of the volume reserved for snapshots
- **snapshotDir** (default: _false_): controls the accessibility of the .snapshot directly

We are going to cover here several topics I often discuss with customers:
- [1- Accessibility and visibility](1_Accessibility_and_visibility): How to configure your infrastructure to access Snapshots  
- [2- Snapshots and NASECO](2_Snapshots_and_NASECO): Snapshots management in the context of the ONTAP-NAS-ECONOMY Trident driver