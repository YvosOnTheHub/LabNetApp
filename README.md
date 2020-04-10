# LabNetApp

## A. Kubernetes v2 (with CSI)

The section has been tested with the Lab-on-Demand Using "Trident with Kubernetes and ONTAP v3.1" which comes with Trident 19.07 already installed on Kubernetes 1.15.3.

Most labs will be done by connecting with Putty to the RHEL3 host (root/Netapp1!).
I assume each scenario will be run in its own directory. Also, you will find a README file for each scenario.

Scenarios
---------
[1.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario01)  Upgrade Trident  
[2.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario02)  Install Prometheus & incorporate Trident's metrics  
[3.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario03)  Configure Grafana & add your first graphs  
[4.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario04)  Configure your first NAS backends & storage classes  
[5.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario05)  Deploy your first app with File storage  
[6.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario06)  Prepare your lab for block storage  
[7.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario07)  Configure your first iSCSI backends & storage classes  
[8.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario08)  Deploy your first app with Block storage  
[9.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario09)  Use the 'import' feature of Trident  
[10.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario10) Consumption control  
[11.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario11) Resize a NFS CSI PVC  
[12.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario12) Using Virtual Storage Pools  
[13.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario13) StatefulSets & Storage consumption  
[14.](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario14) Resize a iSCSI CSI PVC  
[15.] On-Demand Snapshots & Create PVC from Snapshot (_soon_)  

## B. Kubernetes v1 (pre-CSI)

These files are attended to be used with the NetApp LabOnDemand "Using NetApp with Docker and Kubernetes v2.0".
The "Kubernetes_v1" directory contains lots of configuration files to create backends / storage classes / PVC / PODs

Scenarios
---------
1. Upgrade Trident
2. Backends & Storage Classes configuration
3. Quota Management with Kubernetes
4. Test new features released in Trident 18.10 (limitVolumeSize, snapshotReserve & limitAggregateUsage)
5. Create an Apache environment with a Persistent Volume
6. Test new features released in Trident 19.04 (volume import)
7. Migrating an app from a legacy Docker environment to a new Kubernetes cluster
8. Snapshots management with ONTAP-NAS & ONTAP-NAS-ECONOMY


## C. Docker

the "Docker" directory contains several configuration files to create different plugins on the lab

Scenarios
---------
1. Create & Update Trident plugins
2. Play around with clones & Apache