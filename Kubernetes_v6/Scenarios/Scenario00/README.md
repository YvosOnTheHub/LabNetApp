#########################################################################################
# SCENARIO 0: Let's review some Best Practices & advices 
#########################################################################################

As a CSI Driver, Trident provides most of the features proposed by the CNCF standard ([CSI Snapshots](../Scenario13), [CSI Topology](../Scenario15), [Volume Expansion](../Scenario09), ...). However, as a NetApp product, it proposes a lot more good stuff, implemented both at the storage level & in Trident! We will review here a few _Best Practices_, as well as advices I have put together over the years.

## A. Deploying Trident

### 1. **Dedicate a namespace for Trident**

A namespace is a Kubernetes construct that will isolate some resources from other namespaces. It is some kind of Kubernetes tenant, word we often use when referring to ONTAP SVMs. Putting applications in their own namespaces creates a clean & neat environment to manage, with dedicated resources (PVC) & rules. In terms of security, it is pretty wise to install Trident in its own namespace (often called _trident_, funky right?), especially since Trident stores the storage backends credentials & certificates in Kubernetes encrypted secrets.

To see how the installation in action, please refer to the [scenario01](../Scenario01).

### 2. **Choosing the right installation method**

Trident has evolved quite a lot since its creation in 2016. We went from one single method to install this orchestrator to 4 possibilities today:  
- with the binary tridentctl  
- manual installation with the Trident Operator (cf [Scenario01](../Scenario01/1_Operator))  
- automatized installation of the Trident Operator with the Trident Helm Chart (cf [Scenario01](../Scenario01/2_Helm))  
- GitOps principles (cf [Scenario18](../Scenario18))  

Choosing the right method for your environment can be done by answering some of the following questions:  
- Do you need a heavily customized Trident configuration? (which can be achieved by customizing all Trident files with tridentctl)  
- Are you looking for an Operator model which brings self-healing to Trident & easy upgrades?  
- Does you company use Helm to deploy applications on Kubernetes?  
- Does you company follows GitOps principes & manage applications deployement through a Git repository & CD tool (such as ArgoCD)?  

### 3. **Choosing the right Trident driver(s)**  

If you plan on using Trident with an ONTAP based backend, you will have access to 5 different drivers:

- ONTAP-NAS & ONTAP-NAS-ECONOMY (cf [scenario02](../Scenario02))  
- ONTAP-NAS-FLEXGROUP
- ONTAP-SAN & ONTAP-SAN-ECONOMY (cf [scenario05](../Scenario05))  

Choosing the right ones to configure can be tricky the very first time. Here are a few questions that could help you pin point what you need:

- How many PVC are you planning on having on Day1 & over the coming months/years ? And for what total capacity ?
- How many storage platforms will be connected to the container orchestrator ?  
- Are you looking for Block Storage (iSCSI) or File (NFS) ? (cf [scenario19](../Scenario19))  
- Are you looking for RWO, RWX, ROX access modes ? (cf [scenario19](../Scenario19))  
- How much performance do you need? Does it need to be limited or guaranteed? (cf [scenario16](../Scenario16))  
- Are the storage backends shared or dedicated? Do you want to limit storage consumption? (cf [scenario08](../Scenario08))  
- Do you need gigantic flat NFS shares? (that would be a FlexGroup)  

## B. Configuring Trident backends

### 1. **KISS**

I am not referring to love guns... But I advise you to keep things simple. Dont set parameters you don't need just because it looks fancy.  
Perfect example, the _svm_ name is optional, as Trident will find it anyway through the _managementLIF_. You really **only** need if you plan on using Cluster Admin credentials, which are necessary when setting the _limitAggregateUsage_ parameter.  

Another benefit derived from not setting the svm name is for customers that use _Metroclusters_ or _SVM DR_ environments. The _secondary_ SVM's name is slightly different from the _primary_ SVM (example: mysvm => mysvm-mc). When activating the DR, existing volumes are immediatly available on the secondary site, you may even not see any impact depending on how the orchestrator is built on top (stretched or not). However, if you want to create/delete/expand volumes, you first need to update the Trident backend so that the new name is recognized. Not setting the SVM name means one less step in the process.  

### 2. **It's always the network! (isn't it?)**

Before configuring Trident's backends, make sure you have given some thoughts about networking.  
Whereas you use a NAS backend or a SAN backend, there are two parameters to set:

- managementLIF: that is the path Trident uses to talk to the backend
- dataLIF: that is endpoint used by a POD to mount a storage resource

Here are a few notes that will help you build your configuration file:

- Both _managementLIF_ & _dataLIF_ parameters can be configured with IP addresses & FQDN
- The _managementLIF_ parameter can be updated, while **the _dataLIF_ cannot change** (networking is immutable)
- If you don't set a dataLIF, Trident will just pick one & stick with it
- If you are creating a **SAN** backend, **do not configure the _dataLIF_ parameter** (unless specific reasons), as if you do, you will not benefit from multipathing

You will notice in the different scenarios of this GitHub repo that I almost never set the parameters _dataLIF_ & _svm_.

## C. Configuring ONTAP

### 1. **Security is not _BestPractice_, it must be the first thing to consider!**

Security has become a very hot topic. You should then be aware of all the options you have to restrict accesses & encrypt data.  

Here are a few easy things you can set up to tighten your backend security:

- Disable _showmount_ so that no one can see existing volumes from the hosts (cf [scenario14](../Scenario14))  
- Create specific users for Trident with minimal capabilities (API)
- Create network policies to restrict protocols on network interfaces, as SSH is not required (cf [scenario14](../Scenario14))  
- Configure Dynamic Export Policy management for NAS workloads (cf [scenario12](../Scenario12))  
- Configure Bidirectional CHAP for SAN workloads (cf [scenario05](../Scenario05))  

To go even further, know that you can also configure (not covered in this GitHub repo):

- data encryption (with ONTAP NVE, ONTAP NAE or encrypted drives) **(1)**
- transport encryption with IPSec or Kerberos

**(1)** NVE = NetApp Volume Encryption & NAE = NetApp Aggregate Encryption

### 2. **Dedicating SVMs to Trident or not**

A SVM is an ONTAP tenant isolated from its neighbours & on which you can apply specific rules (network isolation, resource consumption, ...).  
Generally speaking it's good practice to dedicate SVMs to Trident, even if only for monitoring your environment. As a Kubernetes admin/user, you dont necessarily need to see what other do other SVMs. Also, management your environment at the tenant level can also help if some day you need to migrate it to another system.

## D. Overall thoughts

### 1. **Who manages what & who can have access to what resource**

When working with Cloud-Native environments, you end up having a lot of different layers (App, Orchestrator, Storage, etc ...), each one often managed by a different team. Soon or later will come on the table the question of controlling resources: 

- the Kubernetes admin may not want an app to use all the host CPU
- the storage admin may not want an app to use all the storage available
- ...

You should know that can you put in place different mechanisms to limit consumption at all levels, while guaranting performance. There is not _one size fits all_ story here, but once you have the cards in your hand, you can start building something quite neat.

Some chapters to read

- Consumption control (cf [scenario08](../Scenario08))  
- Performance control (cf [scenario16](../Scenario16))  

### 2. **Monitoring**

Knowing what is going on on your environment is really important. It can help you detect problems, plan your future, report to your boss, create precise billing, etc... Both Trident & ONTAP have metrics that can be exported. You just need to choose the tool that corresponds to your needs.  

Here are two options that you can put in place in this context:

- Expose metrics to Prometheus from Trident & Harvest, and build dashboards in Grafana to monitor your environment (cf [scenario03](../Scenario03))  
- If reporting, chargeback, bully detection sound necessary, take a look at [Cloud Insight](https://cloud.netapp.com/cloud-insights)  

Maybe a bit off context, but I will still recommand looking at [Spot.io](https://spot.io/products/ocean-suite/) to bring in Continuous Optimization.

Now that you have read this whole page, I invite you to look into the different [scenarios](https://github.com/YvosOnTheHub/LabNetApp), & have fun !
