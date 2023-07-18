#########################################################################################
# SCENARIO 2: Create your first NFS backends for Trident & Storage Classes for Kubernetes
#########################################################################################

**GOAL:**  
Trident needs to know where to create volumes.  
This information sits in objects called backends. It basically contains:

- the driver type (there currently are 10 different drivers available)
- how to connect to the driver (IP, login, password ...)
- some default parameters

For additional information, please refer to:

- https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-postdeployment.html#step-1-create-a-backend
- https://docs.netapp.com/us-en/trident/trident-use/backends.html  

Once you have configured backend, the end user will create PVC against Storage Classes.  
A storage class contains the definition of what an app can expect in terms of storage, defined by some properties (access, media, driver ...)

For additional information, please refer to:

- https://docs.netapp.com/us-en/trident/trident-use/manage-stor-class.html#design-a-storage-class 

Also, installing & configuring Trident + creating Kubernetes Storage Classe is what is expected to be done by the Admin.  

Trident 21.04 introduced the possibility to manage Trident backends directly with _kubectl_, whereas it was previously solely feasible with _tridentctl_.  
Managing backends this way is done with 2 different objects:

- **Secrets** which contain the credentials necessary to connect to the storage (login/pwd or certificate)
- **TridentBackendConfig** which is a new CRD that contains all the parameters related to this backend.

Note that _secrets_ can be used by multiple _TridentBackendConfigs_.

<p align="center"><img src="Images/scenario2.jpg"></p>

This chapter will guide you through three different methods to confiture a Trident backend:  
[1.](1_Local_User) with an ONTAP local user  
[2.](2_Cert) with SSL certificates  
[3.](3_AD_User) with an AD user
