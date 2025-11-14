#########################################################################################
# SCENARIO 27: Demystifying Virtual Machines
#########################################################################################

Virtual Machines are becoming one the major workloads that run in Kubernetes, especially when it comes to storage consumption.  
Though the underlying objects are still PODs and PVCs, there are plenty of new ones that need (or not) specific care.  

You will find in this scenario multiple chapters linked to Virtual Machines, from creation to modification, all linked to storage management. This is only the tip of the iceberg, as the topic is quite large, but it might clear up some fog in your head (as it did for me).  

Before going any further, make sure you have configured the lab so that it is ready to host Virtual Machines.  
This is all described in the [Addenda15](../../Addendum/Addenda15/).  
You can also find there a *all_in_one_rhel3.sh* script that will perform the following tasks:  
- install KubeVirt: the engine that manages Virtual Machines  
- install virtctl: tool to interact with Virtual Machines  
- install CDI (Container Data Importer): operator that can be used to build boot disks for VMs 
- install a Dashboard for your VMs  

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p> 

**ATTENTION:**    
There is one important concept that must be understood before you start working with Virtual Machines.  
Unlike VMware, there is no _datastore_ concept with KubeVirt. Each disk is going to be represented as a PVC.  
In other hypervisors, like VMware, the datastore is connected to the storage. Disks (_vmdk_) are just files within that volume.  
When working with KubeVirt, you quickly understand that you must pay attention to the architecture of the storage layer.  
Managing 10 datastores (with 100 disks each) is very different from managing 1000 PVC, for placement, but also for protection.

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p> 

And now, let the fun start:  
[1.](./1_VMCreation) Creating a Virtual Machine  
[2.](./2_SecondaryDisks/) Secondary disks management