# LabNetApp

This repo was created to help you better understand the benefits you can get from Trident, for both the end-user & the admin teams. 
You will find several exercises, described in a step-by-step fashion, that you can use on the NetApp Lab-on-Demand  or on your own environment.  

With the introduction of Trident Protect in November 2024, extra scenarios have been added to see how you can protect stateful applications!  

<!-- ## A. Kubernetes v6 (with CSI) :new:  -->

The section has been tested with the Lab-on-Demand Using [**Trident with Kubernetes Advanced v6.0**](https://labondemand.netapp.com/lab/tridentadvlab) which comes with Trident :trident: 24.02.0 already installed on Kubernetes 1.29.4.  

**Most labs will be done by connecting with Putty to the RHEL3 host (root/Netapp1!).  
I assume each scenario will be run in its own directory. Also, you will find a README file for each scenario.**  

Last, there are plenty of commands to write or copy/paste.  
Try using some of the shortcuts you will find in the the [Addenda0](Kubernetes_v5/Addendum/Addenda00) !  

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>  

```diff
- You may have seen that starting in November 2020, there are now limits on how many pull requests can be done on the Docker Hub.  
- As this lab was created with an _anonymous_ user, please read carefully the Addenda08 before starting this lab.
```

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>  

## Trident Scenarios (Dynamic Storage Provisionning)  

[0.](Kubernetes_v6/Trident_Scenarios/Scenario00) Best Practices & Advices  
[1.](Kubernetes_v6/Trident_Scenarios/Scenario01) Upgrade/Install Trident (25.06.1)  
[2.](Kubernetes_v6/Trident_Scenarios/Scenario02) NAS backends for Trident & Storage Classes for Kubernetes  
[3.](Kubernetes_v6/Trident_Scenarios/Scenario03) Prometheus, Grafana & Harvest integration  
[4.](Kubernetes_v6/Trident_Scenarios/Scenario04) Create your first NAS Apps  
[5.](Kubernetes_v6/Trident_Scenarios/Scenario05) Block backends for Trident & Storage Classes for Kubernetes  
[6.](Kubernetes_v6/Trident_Scenarios/Scenario06) Create your first SAN Apps  
[7.](Kubernetes_v6/Trident_Scenarios/Scenario07) Importing data with Trident  
[8.](Kubernetes_v6/Trident_Scenarios/Scenario08) Consumption control  
[9.](Kubernetes_v6/Trident_Scenarios/Scenario09) Expanding Persistent Volumes  
[10.](Kubernetes_v6/Trident_Scenarios/Scenario10) Using Virtual Storage Pools  
[11.](Kubernetes_v6/Trident_Scenarios/Scenario11) StatefulSets & Storage consumption  
[12.](Kubernetes_v6/Trident_Scenarios/Scenario12) Dynamic export policy management  
[13.](Kubernetes_v6/Trident_Scenarios/Scenario13) Snapshots here & snapshots there, snapshots everywhere  
[14.](Kubernetes_v6/Trident_Scenarios/Scenario14) About security  
[15.](Kubernetes_v6/Trident_Scenarios/Scenario15) Caring about location or about CSI Topology  
[16.](Kubernetes_v6/Trident_Scenarios/Scenario16) Performance control  
[17.](Kubernetes_v6/Trident_Scenarios/Scenario17) How to configure HAProxy between Trident & ONTAP  
[18.](Kubernetes_v6/Trident_Scenarios/Scenario18) Kubernetes, Trident & GitOps  
[19.](Kubernetes_v6/Trident_Scenarios/Scenario19) Let's talk about protocols & access modes !  
[20.](Kubernetes_v6/Trident_Scenarios/Scenario20) About Generic Ephemeral Volumes  
[21.](Kubernetes_v6/Trident_Scenarios/Scenario21) Persistent Volumes and Multi Tenancy  
[22.](Kubernetes_v6/Trident_Scenarios/Scenario22) Crossing the borders    
[23.](Kubernetes_v6/Trident_Scenarios/Scenario23) Naming conventions  
[24.](Kubernetes_v6/Trident_Scenarios/Scenario24) Migrating volumes (snapmirror integration)  
[25.](Kubernetes_v6/Trident_Scenarios/Scenario25) Storage & Policy Management  
[26.](Kubernetes_v6/Trident_Scenarios/Scenario26) Working in parallel   

## Trident Protect Scenarios (Application data protection)  

[1.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario01) Lab Setup  
[2.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario02) Trident Protect installation  
[3.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario03) S3 Bucket connectivity  
[4.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario04) Monitoring  
[5.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario05) Tests scenario with Busybox (without hooks)  
[6.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario06) Hook me up before you go-go!  
[7.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario07) Be Selective  
[8.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario08) Protecting Applications with GitOps  
[9.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario09) Pacman to the rescue  
[10.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario10) One bucket or two buckets, that is the question  
[11.](Kubernetes_v6/Trident_Protect_Scenarios/Scenario11) Protecting Virtual Machines  

## Addendum  

[0.](Kubernetes_v6/Addendum/Addenda00) Useful commands  
[1.](Kubernetes_v6/Addendum/Addenda01) Add a node to the cluster  
[2.](Kubernetes_v6/Addendum/Addenda02) Specify a default storage class  
[3.](Kubernetes_v6/Addendum/Addenda03) Allow user PODs on the master node  
[4.](Kubernetes_v6/Addendum/Addenda04) Install Ansible on RHEL3 (Kubernetes Control Plane)  
[5.](Kubernetes_v6/Addendum/Addenda05) Install the Kubernetes dashboard  
[6.](Kubernetes_v6/Addendum/Addenda06) Install cool tools  
[7.](Kubernetes_v6/Addendum/Addenda07) How to install & prepare HAProxy  
[8.](Kubernetes_v6/Addendum/Addenda08) How to run this lab with the Docker hub rate limiting  
[9.](Kubernetes_v6/Addendum/Addenda09) How to create a S3 Bucket on ONTAP (_svm_S3_)  
[10.](Kubernetes_v6/Addendum/Addenda10) Set up a simple Source Code Repository  
[11.](Kubernetes_v6/Addendum/Addenda11) Install ArgoCD in this lab  
[12.](Kubernetes_v6/Addendum/Addenda12) Create a second Kubernetes cluster on the hosts _RHEL4_ & _RHEL5_  
[13.](Kubernetes_v6/Addendum/Addenda13) Create a new SVM (_svm_secondary_)  
[14.](Kubernetes_v6/Addendum/Addenda14) Upgrade Kubernetes  
[15.](Kubernetes_v6/Addendum/Addenda15) Install and configure KubeVirt  

<!-- OLD CONTENT

Kubernetes v5: https://labondemand.netapp.com/node/240
Scenarios  
---------  
[0.](Kubernetes_v5/Scenarios/Scenario00) Best Practices & Advices  
[1.](Kubernetes_v5/Scenarios/Scenario01) Upgrade/Install Trident (23.07.0) :arrows_counterclockwise:  
[2.](Kubernetes_v5/Scenarios/Scenario02) Configure your first NAS backends & storage classes :arrows_counterclockwise:  
[3.](Kubernetes_v5/Scenarios/Scenario03) Upgrade and use Prometheus, Grafana & Harvest  
[4.](Kubernetes_v5/Scenarios/Scenario04) Deploy your first app with File storage  
[5.](Kubernetes_v5/Scenarios/Scenario05) Configure your first iSCSI backends & storage classes  
[6.](Kubernetes_v5/Scenarios/Scenario06) Deploy your first app with Block storage  
[7.](Kubernetes_v5/Scenarios/Scenario07) Importing data with Trident :arrows_counterclockwise:  
[8.](Kubernetes_v5/Scenarios/Scenario08) Consumption control  
[9.](Kubernetes_v5/Scenarios/Scenario09) Expanding Persistent Volumes  
[10.](Kubernetes_v5/Scenarios/Scenario10) Using Virtual Storage Pools  
[11.](Kubernetes_v5/Scenarios/Scenario11) StatefulSets & Storage consumption  
[12.](Kubernetes_v5/Scenarios/Scenario12) Dynamic export policy management  
[13.](Kubernetes_v5/Scenarios/Scenario13) Snapshots here & snapshots there, snapshot everywhere :arrows_counterclockwise:  
[14.](Kubernetes_v5/Scenarios/Scenario14) About security :arrows_counterclockwise:  
[15.](Kubernetes_v5/Scenarios/Scenario15) Caring about location or about CSI Topology  
[16.](Kubernetes_v5/Scenarios/Scenario16) Performance control  
[17.](Kubernetes_v5/Scenarios/Scenario17) How to configure HAProxy between Trident & ONTAP  
[18.](Kubernetes_v5/Scenarios/Scenario18) Kubernetes, Trident & GitOps  
[19.](Kubernetes_v5/Scenarios/Scenario19) Let's talk about protocols & access modes !  
[20.](Kubernetes_v5/Scenarios/Scenario20) About Generic Ephemeral Volumes  
[21.](Kubernetes_v5/Scenarios/Scenario21) Persistent Volumes and Multi Tenancy  
[22.](Kubernetes_v5/Scenarios/Scenario22) Cross Namespace Volume Access  

Addendum
--------
[0.](Kubernetes_v5/Addendum/Addenda00) Useful commands  
[1.](Kubernetes_v5/Addendum/Addenda01) Add a node to the cluster  
[2.](Kubernetes_v5/Addendum/Addenda02) Specify a default storage class  
[3.](Kubernetes_v5/Addendum/Addenda03) Allow user PODs on the master node  
[4.](Kubernetes_v5/Addendum/Addenda04) Install Ansible on RHEL3 (Kubernetes Master)  
[5.](Kubernetes_v5/Addendum/Addenda05) Install a Load Balancer (MetalLB) :arrows_counterclockwise:  
[6.](Kubernetes_v5/Addendum/Addenda06) Install the Kubernetes dashboard  
[7.](Kubernetes_v5/Addendum/Addenda07) Install cool tools  
[8.](Kubernetes_v5/Addendum/Addenda08) How to run this lab with the Docker hub rate limiting  
[9.](Kubernetes_v5/Addendum/Addenda09) How to install & prepare HAProxy  
[10.](Kubernetes_v5/Addendum/Addenda10) How to create a S3 Bucket on ONTAP  
[11.](Kubernetes_v5/Addendum/Addenda11) Set up a simple Source Code Repository  
[12.](Kubernetes_v5/Addendum/Addenda12) Install ArgoCD in this lab  


## A. Kubernetes v4

Scenarios  
---------  
[0.](Kubernetes_v4/Scenarios/Scenario00) Best Practices & Advices  
[1.](Kubernetes_v4/Scenarios/Scenario01) Upgrade/Install Trident (v21.07.2)  
[2.](Kubernetes_v4/Scenarios/Scenario02) Configure your first NAS backends & storage classes  
[3.](Kubernetes_v4/Scenarios/Scenario03) Upgrade and use Prometheus, Grafana & Harvest  
[4.](Kubernetes_v4/Scenarios/Scenario04) Deploy your first app with File storage  
[5.](Kubernetes_v4/Scenarios/Scenario05) Configure your first iSCSI backends & storage classes  
[6.](Kubernetes_v4/Scenarios/Scenario06) Deploy your first app with Block storage  
[7.](Kubernetes_v4/Scenarios/Scenario07) Use the 'import' feature of Trident  
[8.](Kubernetes_v4/Scenarios/Scenario08) Consumption control  
[9.](Kubernetes_v4/Scenarios/Scenario09) Expanding Persistent Volumes  
[10.](Kubernetes_v4/Scenarios/Scenario10) Using Virtual Storage Pools  
[11.](Kubernetes_v4/Scenarios/Scenario11) StatefulSets & Storage consumption  
[12.](Kubernetes_v4/Scenarios/Scenario12) Dynamic export policy management  
[13.](Kubernetes_v4/Scenarios/Scenario13) Kubernetes CSI Snapshots & PVC from Snapshot workflows  
[14.](Kubernetes_v4/Scenarios/Scenario14) About security  
[15.](Kubernetes_v4/Scenarios/Scenario15) Caring about location or about CSI Topology  
[16.](Kubernetes_v4/Scenarios/Scenario16) Performance control  
[17.](Kubernetes_v4/Scenarios/Scenario17) How to configure HAProxy between Trident & ONTAP  
[18.](Kubernetes_v4/Scenarios/Scenario18) Kubernetes, Trident & GitOps  
[19.](Kubernetes_v4/Scenarios/Scenario19) Let's talk about protocols & access modes !  
[20.](Kubernetes_v4/Scenarios/Scenario20) About Generic Ephemeral Volumes  
[21.](Kubernetes_v4/Scenarios/Scenario21) Persistent Volumes and Virtual vClusters :new:  

Addendum
--------
[0.](Kubernetes_v4/Addendum/Addenda00) Useful commands  
[1.](Kubernetes_v4/Addendum/Addenda01) Add a node to the cluster  
[2.](Kubernetes_v4/Addendum/Addenda02) Specify a default storage class  
[3.](Kubernetes_v4/Addendum/Addenda03) Allow user PODs on the master node  
[4.](Kubernetes_v4/Addendum/Addenda04) Install Ansible on RHEL3 (Kubernetes Master)  
[5.](Kubernetes_v4/Addendum/Addenda05) Install a Load Balancer (MetalLB)  
[6.](Kubernetes_v4/Addendum/Addenda06) Install the Kubernetes dashboard  
[7.](Kubernetes_v4/Addendum/Addenda07) Install cool tools :arrows_counterclockwise:  
[8.](Kubernetes_v4/Addendum/Addenda08) How to run this lab with the Docker hub rate limiting  
[9.](Kubernetes_v4/Addendum/Addenda09) How to upgrade ONTAP  
[10.](Kubernetes_v4/Addendum/Addenda10) How to install & prepare HAProxy  
[11.](Kubernetes_v4/Addendum/Addenda11) How to create a S3 Bucket on ONTAP  
[12.](Kubernetes_v4/Addendum/Addenda12) Set up a simple Source Code Repository  
[13.](Kubernetes_v4/Addendum/Addenda13) Install ArgoCD in this lab  
[14.](Kubernetes_v4/Addendum/Addenda14) Upgrade Kubernetes :new: 

## B. Kubernetes v2 (with CSI)

The section has been tested with the Lab-on-Demand Using "**Trident with Kubernetes and ONTAP v3.1**" which comes with Trident :trident: 19.07 already installed on Kubernetes 1.15.3.

:boom:  
Most labs will be done by connecting with Putty to the RHEL3 host (root/Netapp1!).  
I assume each scenario will be run in its own directory. Also, you will find a README file for each scenario.  

Last, there are plenty of commands to write or copy/paste.  
Try using some of the shortcuts you will find in the the Addenda0!  
:boom:  

Scenarios (updated for Trident 20.10)
---------
[1.](Kubernetes_v2/Scenarios/Scenario01) Install/Upgrade Trident  
[2.](Kubernetes_v2/Scenarios/Scenario02) Configure your first NAS backends & storage classes  
[3.](Kubernetes_v2/Scenarios/Scenario03) Install and use Prometheus & Grafana :arrows_counterclockwise:  
[4.](Kubernetes_v2/Scenarios/Scenario04) Deploy your first app with File storage  
[5.](Kubernetes_v2/Scenarios/Scenario05) Configure your first iSCSI backends & storage classes  
[6.](Kubernetes_v2/Scenarios/Scenario06) Deploy your first app with Block storage  
[7.](Kubernetes_v2/Scenarios/Scenario07) Use the 'import' feature of Trident  
[8.](Kubernetes_v2/Scenarios/Scenario08) Consumption control  
[9.](Kubernetes_v2/Scenarios/Scenario09) Resize a NFS CSI PVC  
[10.](Kubernetes_v2/Scenarios/Scenario10) Using Virtual Storage Pools  
[11.](Kubernetes_v2/Scenarios/Scenario11) StatefulSets & Storage consumption  
[12.](Kubernetes_v2/Scenarios/Scenario12) Resize a iSCSI CSI PVC (*requires Kubernetes 1.16 minimum*)  
[13.](Kubernetes_v2/Scenarios/Scenario13) Dynamic export policy management  
[14.](Kubernetes_v2/Scenarios/Scenario14) Kubernetes CSI Snapshots & PVC from Snapshot workflows (*requires Kubernetes 1.17 minimum*)  
[15.](Kubernetes_v2/Scenarios/Scenario15) About security  
[16.](Kubernetes_v2/Scenarios/Scenario16) Caring about location or about CSI Topology (*requires Kubernetes 1.17 minimum*)  

Addendum
--------
[0.](Kubernetes_v2/Addendum/Addenda00) Useful commands  
[1.](Kubernetes_v2/Addendum/Addenda01) Add a node to the cluster  
[2.](Kubernetes_v2/Addendum/Addenda02) Specify a default storage class  
[3.](Kubernetes_v2/Addendum/Addenda03) Allow user PODs on the master node  
[4.](Kubernetes_v2/Addendum/Addenda04) Upgrade your Kubernetes cluster (1.15 => 1.16 => 1.17 => 1.18)  
[5.](Kubernetes_v2/Addendum/Addenda05) Prepare ONTAP for block storage  
[6.](Kubernetes_v2/Addendum/Addenda06) Install Ansible on RHEL3 (Kubernetes Master)  
[7.](Kubernetes_v2/Addendum/Addenda07) Install a Load Balancer (MetalLB)  
[8.](Kubernetes_v2/Addendum/Addenda08) Install the Kubernetes dashboard  

## C. Kubernetes v1 pre-CSI (**retired**, but can still be useful)

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

## D. Docker (**retired**, but can still be useful)

the "Docker" directory contains several configuration files to create different plugins on the lab

Scenarios
---------
1. Create & Update Trident plugins
2. Play around with clones & Apache
-->

<!-- ICONS
:new:
:arrows_counterclockwise:
-->