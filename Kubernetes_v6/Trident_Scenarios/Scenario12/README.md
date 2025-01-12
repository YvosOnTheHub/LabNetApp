#########################################################################################
# SCENARIO 12: Dynamic Export Policy Management
#########################################################################################

**GOAL:**  
Trident 20.04 introduced the dynamic export policy feature for the 3 different ONTAP-NAS backends.  
Letting Trident manage the export policies allows to reduce the amount of administrative tasks, especially when clusters scale up&down.

The configuration of this feature is done in the Trident Backend object. The lab backends already have this feature enabled.  
Let's see what parameters must be used to enable this:  
- *autoExportPolicy*: enables the feature  
- *autoExportCIDRs*: defines the address blocks to use (optional parameter)  

## A. Setup the backend with a CIDR

Let's retrieve the IP adresses of all nodes of the cluster:

```bash
$ kubectl get nodes -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
win1    192.168.0.72
win2    192.168.0.73
```

Let's see how that translates in ONTAP. Open a new Putty session on 'cluster1', using admin/Netapp1!  
What export policies do we see:  
```bash
cluster1::> export-policy show -vserver nassvm
Vserver          Policy Name
---------------  -------------------
nassvm           default
nassvm           trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
2 entries were displayed.
```

The _default_ policy is always present, while the other one has dynamically been created by Trident.  
Notice that the name of the policy contains the UUID of the Trident Backend:
```bash
$ kubectl get -n trident tbe tbe-7cf6s
NAME        BACKEND         BACKEND UUID
tbe-7cf6s   BackendForNFS   11d28fb4-6cf5-4c59-931d-94b8d8a5e061
```

Now, let's look at the rule set by Trident for this backend:  
```bash
cluster1::> export-policy rule show -vserver nassvm -policyname trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             1       nfs      192.168.0.62          any
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             2       nfs      192.168.0.63          any
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             3       nfs      192.168.0.61          any
3 entries were displayed.
```

You can see that there is a rule for every single Unix node present in the cluster. No other host will be able to mount a resource present on this tenant.  

## B. Setup the backend without a CIDR

Let's start by creating a new backend similar to the previous one, but without the _autoExportCIDRs_ parameter:  
```bash
$ kubectl create -f backend-tbc-nfs-no-cidr.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-nfs-no-cidr created

$ kubectl get tbe -n trident tbe-98pw6
NAME        BACKEND               BACKEND UUID
tbe-98pw6   BackendForNFSNoCIDR   9b79b97e-c8b5-482c-93ff-5f04cd7ad28b
```

Now let's look at the rule set by Trident for this backend:  
```bash
cluster1::> export-policy rule show -vserver nassvm -policyname trident-9b79b97e-c8b5-482c-93ff-5f04cd7ad28b
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident-9b79b97e-c8b5-482c-93ff-5f04cd7ad28b
                             1       nfs      192.168.0.61,         any
                                              192.168.26.0
nassvm       trident-9b79b97e-c8b5-482c-93ff-5f04cd7ad28b
                             2       nfs      192.168.0.62,         any
                                              192.168.28.64
nassvm       trident-9b79b97e-c8b5-482c-93ff-5f04cd7ad28b
                             3       nfs      192.168.0.63,         any
                                              192.168.25.64
3 entries were displayed.
```

Notice the difference?  
Before creating the rules, Trident looked at all the unicast IP addresses on each node & used them on the storage backend.  
The 3 new IP addresses belong to the _192.168.24.0/21_ subnet which is used by Calico (Kubernetes network) on this configuration.

## C. SVM Root export policy

As stated in the documentation, you must ensure that the root junction in your SVM has a pre-created export policy with an export rule that permits the node CIDR block (such as the *default* export policy). All volumes created by Trident are mounted under the root junction.  
Let's look at what we have in the LabOnDemand

```bash
cluster1::> export-policy rule show -vserver nassvm -policyname default
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       default         1       nfs      0.0.0.0/24            any
```

There you go, now, all applications created with these backends are going to have access to storage, while adding an extra level of security.

## C. More fun to prove my point

Let's see what happens if you add a new node to the cluster.
Once you are done with the [Addenda01](../../Addendum/Addenda01), you should have:  
```bash
$ kubectl get nodes -l kubernetes.io/os=linux
NAME    STATUS   ROLES    AGE   VERSION
NAME    STATUS   ROLES           AGE   VERSION
rhel1   Ready    <none>          92d   v1.29.4
rhel2   Ready    <none>          92d   v1.29.4
rhel3   Ready    control-plane   92d   v1.29.4
rhel4   Ready    <none>          33s   v1.29.4

$ kubectl get nodes -l kubernetes.io/os=linux -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
rhel4   192.168.0.64
```

By definition, Trident should have dynamically added a new entry in the export-policy:  
```bash
cluster1::> export-policy rule show -vserver nassvm -policyname trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             1       nfs      192.168.0.62          any
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             2       nfs      192.168.0.63          any
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             3       nfs      192.168.0.61          any
nassvm       trident-11d28fb4-6cf5-4c59-931d-94b8d8a5e061
                             4       nfs      192.168.0.64          any
4 entries were displayed.
```

Tadaaaa !

## D. Finally some optional cleanup

```bash
$ kubectl delete -n trident tbc backend-tbc-nfs-no-cidr
tridentbackendconfig.trident.netapp.io "backend-tbc-nfs-no-cidr" deleted
```

## E. What's next

You can now move on to:  
- [Scenario13](../Scenario13): CSI Snapshots Management

Maybe you could learn something in the different [addenda](https://github.com/YvosOnTheHub/LabNetApp)?
Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
