## LabNetApp

These files are attended to be used with the NetApp LabOnDemand "Docker & Kubernetes".


## A. Kubernetes v2 (with CSI)

The "Kubernetes" directory contains lots of configuration files to create backends / storage classes / PVC / PODs
The section has been tested with the Lab-on-Demand Using "Trident with Kubernetes and ONTAP v3.1" which comes with Trident 19.07 already installed on Kubernetes 1.15.3.

Most labs will be done by connecting with Putty to the RHEL3 host (root/Netapp1!).
I assume each scenario will be run in its own directory.

Scenarios
---------
1.  Upgrade Trident
2.  Install Prometheus & incorporate Trident's metrics
3.  Configure Grafana & add your first graphs
4.  Configure your first NAS backends & storage classes
5.  Deploy your first app with File storage
6.  Prepare your lab for block storage
7.  Configure your first iSCSI backends & storage classes
8.  Deploy your first app with Block storage
9.  Use the 'import' feature of Trident
10. Consumption control

## B. Kubernetes v1 (pre-CSI)

The "Kubernetes" directory contains lots of configuration files to create backends / storage classes / PVC / PODs

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