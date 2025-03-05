#########################################################################################
# SCENARIO 22: Crossing borders
#########################################################################################

Persistent Volume Claims are namespace bound objects.  
As such, data cannot be shared or copied between 2 namespaces...  

Comes Trident with 2 features:  
- Cross Namespace Volume Access (CNVA): grants rights to secondary namespaces to mount a volume  
- Cross Namespace Volume Clone (CNVC): allows you to clone volumes between namespaces  


One use case for the **CNVA** feature would be to use one volume where all namespaces write some data (logs for instance) in various folders. The same volume would then be mounted in another namespace to read & analyse the data.  

For **CNVC**, the perfect example can be found with virtualization workloads (KubeVirt or OpenShift Virtualization).  
Creating new VMs based on templates often means copying data in a new namespace.  
With Trident 25.02, you can now:  
- store templates in a specific namespace  
- rapidly & efficiently create new VMs based on those templates in new namespaces.  

CNVC benefits from the ONTAP FlexClone feature, which creates a new volume that shares block with its parent volume (the template).  
Also, whatever size the template is, the clone will always be ultra fast.

Check out those 2 features:  
- [CNVA](./1_CNVA/)  
- [CNVC](./2_CNVC/)