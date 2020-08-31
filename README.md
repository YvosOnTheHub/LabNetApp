# LabNetApp

## A. Kubernetes v2 (with CSI)

The section has been tested with the Lab-on-Demand Using "Trident with Kubernetes and ONTAP v3.1" which comes with Trident :trident: 19.07 already installed on Kubernetes 1.15.3.

:boom:  
Most labs will be done by connecting with Putty to the RHEL3 host (root/Netapp1!).  
I assume each scenario will be run in its own directory. Also, you will find a README file for each scenario.  

Last, there are plenty of commands to write or copy/paste.  
Try using some of the shortcuts you will find in the the Addenda0!  
:boom:  

Scenarios (updated for Trident 20.07)
---------
[1.](Kubernetes_v2/Scenarios/Scenario01) Install/Upgrade Trident :arrows_counterclockwise:  
[2.](Kubernetes_v2/Scenarios/Scenario02) Configure your first NAS backends & storage classes :arrows_counterclockwise:  
[3.](Kubernetes_v2/Scenarios/Scenario03) Install and use Prometheus & Grafana :arrows_counterclockwise:  
[4.](Kubernetes_v2/Scenarios/Scenario04) Deploy your first app with File storage  
[5.](Kubernetes_v2/Scenarios/Scenario05) Configure your first iSCSI backends & storage classes :arrows_counterclockwise:  
[6.](Kubernetes_v2/Scenarios/Scenario06) Deploy your first app with Block storage  
[7.](Kubernetes_v2/Scenarios/Scenario07) Use the 'import' feature of Trident :arrows_counterclockwise:  
[8.](Kubernetes_v2/Scenarios/Scenario08) Consumption control  
[9.](Kubernetes_v2/Scenarios/Scenario09) Resize a NFS CSI PVC  
[10.](Kubernetes_v2/Scenarios/Scenario10) Using Virtual Storage Pools  
[11.](Kubernetes_v2/Scenarios/Scenario11) StatefulSets & Storage consumption  
[12.](Kubernetes_v2/Scenarios/Scenario12) Resize a iSCSI CSI PVC (*requires Kubernetes 1.16 minimum*)  
[13.](Kubernetes_v2/Scenarios/Scenario13) Dynamic export policy management  
[14.](Kubernetes_v2/Scenarios/Scenario14) Kubernetes CSI Snapshots & PVC from Snapshot workflows (*requires Kubernetes 1.17 minimum*)  

Addendum
--------
[0.](Kubernetes_v2/Addendum/Addenda00) Useful commands  
[1.](Kubernetes_v2/Addendum/Addenda01) Add a node to the cluster  
[2.](Kubernetes_v2/Addendum/Addenda02) Specify a default storage class  
[3.](Kubernetes_v2/Addendum/Addenda03) Allow user PODs on the master node  
[4.](Kubernetes_v2/Addendum/Addenda04) Upgrade your Kubernetes cluster (1.15 => 1.16 => 1.17 => 1.18)  
[5.](Kubernetes_v2/Addendum/Addenda05) Prepare ONTAP for block storage  
[6.](Kubernetes_v2/Addendum/Addenda06) Install Ansible on RHEL3 (Kubernetes Master)  
[7.](Kubernetes_v2/Addendum/Addenda07) Install a Load Balancer (MetalLB) :new:  
[8.](Kubernetes_v2/Addendum/Addenda08) Install the Kubernetes dashboard :new:  

## B. Kubernetes v1 pre-CSI (**retired**, but can still be useful)

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


## C. Docker (**retired**, but can still be useful)

the "Docker" directory contains several configuration files to create different plugins on the lab

Scenarios
---------
1. Create & Update Trident plugins
2. Play around with clones & Apache