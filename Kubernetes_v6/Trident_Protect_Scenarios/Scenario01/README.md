#########################################################################################
# SCENARIO 1: Lab Setup
#########################################################################################

>>>NetApp Trident protect provides advanced application data management capabilities that enhance the functionality and availability of stateful Kubernetes applications backed by NetApp ONTAP storage systems and the NetApp Trident CSI storage provisioner. Trident protect simplifies the management, protection, and movement of containerized workloads across public clouds and on-premises environments. It also offers automation capabilities through its API and CLI.

Here are the features provided by Trident Protect:  
- Consistent application snapshot  
- Consistent application backup  
- Restore (in-place or somewhere else)  
- Application disaster recovery  
- Application cloning

The default lab configuration does not permit testing all of those.  
Let's see how we can customize this environment.  

This chapter will guide you through the following tasks:  
- Trident update  
- Extra Hosts start up  
- Secondary Kubernetes cluster creation  
- SVM creation for S3 (to store applications' metadata & backups)  
- Secondary SVM creation  
- Peering between the 2 NFS SVM (requirement for SnapMirror)  
- Trident configuration on the secondary cluster  

An _all_in_one.sh_ script is available in this folder to run the whole setup for you.  

## A. Kubernetes Windows nodes

In order to avoid Trident Protect installation on the windows nodes, let's add an annotation to them:  
```bash
kubectl taint nodes win1 win=true:NoSchedule
kubectl taint nodes win2 win=true:NoSchedule
```

## B. Trident update  

Trident Protect is compatible with Trident 24.02 (with ACP installed).  
However, I recommend using Trident 24.10 to get the best of both products.  

The Trident upgrade to 24.10 is already documented [here](../../Trident_Scenarios/Scenario01/).  
You can follow the scenario for this upgrade, or you can directly run the following script:  
```bash
sh ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario01/1_Helm/all_in_one.sh
```

## C. Hosts _RHEL4_ & _RHEL5_ start up  

The lab contains two hosts that are offline by default (_RHEL4_ & _RHEL5_).  
We are going to use them to build our secondary Kubernetes cluster.  

In order to power them on, you need to navigate to the Lab on Demand "MyLabs" page, and click on the "VM Status" button corresponding to the instance of your lab:  
<p align="center"><img src="Images/lab_status.png" width="512"></p>

From there, you can easily start those 2 hosts.  

## D. Secondary Kubernetes cluster creation and setup 

A secondary Kubernetes cluster is required to test the following features:  
- Application disaster recovery  
- Application restore to a different cluster  

This is also already documented [here](../../Addendum/Addenda12/).  
That chapter will perform the following tasks:  
- Create a new 2 nodes Kubernetes cluster  
- Install Calico (Network management)  
- Install MetalLB (Load Balancer)  
- Install Trident 24.10  
- Install a Snapshot Controller & a default Volume Snapshot Class  

If don't want to run this configuration manually, you can also use the following (on the host _RHEL3_).  
Those 2 lines will copy a script to the host RHEL5 & execute it:  
```bash
scp -p ~/LabNetApp/Kubernetes_v6/Addendum/Addenda12/all_in_one.sh rhel5:
ssh -o "StrictHostKeyChecking no" root@rhel5 -t "sh all_in_one.sh"
```

## E. Secondary SVM Creation  

A secondary SVM is required to test the following features:  
- Application disaster recovery  
- Application restore to a different cluster  

Creating a secondary SVM is already documented [here](../../Addendum/Addenda13/).  

Note that Ansible must be already installed & configured. 
If you haven't done it just it, you can also refer to the [Addenda04](../../Addendum/Addenda04/) or simply run:  
```bash
sh ~/LabNetApp/Kubernetes_v6/Addendum/Addenda04/all_in_one.sh
```

The IP addresses configured for that environment are the following:  
- Managemement LIF: 192.168.0.140  
- Data LIF NFS: 192.168.0.141  
- Data LIF iSCSI: 192.168.0.142  

The user created for Trident is called _trident_. It has a _vsadmin_ role.

## F. Peering between the 2 NAS SVM  

In order to use the Disaster Recovery feature of Trident Protect, you first need to peer the 2 storage environments.  
In a nutshell, peering 2 clusters simply means they know each other and are ready for mirroring.  
A playbook is already available to perform such configuration:  
```bash
ansible-playbook ~/LabNetApp/Kubernetes_v6/Trident_Scenarios/Scenario24/svm_peering.yaml
```

## G. SVM creation for S3

A S3 Compatible bucket is required by Trident Protect to:  
- Save all the application's metadata  
- Host the persistent volumes content when performing a backup  

Creating a S3 SVM is already documented [here](../../Addendum/Addenda09/).  
There is an ansible playbook provided in that Addenda to help you achieve your goal.  

Also you will need the bucket _access key_ & _secret_ when creating Trident Protect appvaults.  
You can redirect the output of the Ansible playbook to a local file to save those keys for later:  
```bash
ansible-playbook ~/LabNetApp/Kubernetes_v6/Addendum/Addenda09/svm_S3_setup.yaml > /root/ansible_S3_SVM_result.txt
```
If you have not done so, no worries, you can also retrieve those keys with the ONTAP CLI.  

Last, the IP address (endpoint) configured for the bucket is the following: 192.168.0.230  

## H. Trident configuration on the secondary cluster  

The last part of this chapter is the Trident configuration on the secondary cluster.  
The following will:  
- Create a Trident secret  
- Create a Trident Backend Config (ONTAP-NAS / NFS)  
- Create a Storage Class

```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: svm-credentials
  namespace: trident
type: Opaque
stringData:
  username: trident
  password: Netapp1!
---
apiVersion: trident.netapp.io/v1
kind: TridentBackendConfig
metadata:
  name: backend-nfs
  namespace: trident
spec:
  version: 1
  backendName: nfs
  storageDriverName: ontap-nas
  managementLIF: 192.168.0.140
  autoExportCIDRs:
  - 192.168.0.0/24
  autoExportPolicy: true
  credentials:
    name: svm-credentials
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc-nfs
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  storagePools: "nfs:aggr2"
allowVolumeExpansion: true
EOF
```

Afer completing all these actions, you can proceed to the [second scenario](../Scenario02/) which will show you how to install Trident Protect.  