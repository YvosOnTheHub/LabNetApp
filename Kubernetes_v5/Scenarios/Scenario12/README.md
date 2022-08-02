#########################################################################################
# SCENARIO 12: Dynamic Export Policy Management
#########################################################################################

**GOAL:**  
Trident 20.04 introduced the dynamic export policy feature for the 3 different ONTAP-NAS backends.  
Letting Trident manage the export policies allows to reduce the amount of administrative tasks, especially when clusters scale up&down.

The configuration of this feature is done in the Trident Backend object. There 2 different json files in this directory that will help you discover how to use it.  
2 options can be used here:  

- *autoExportPolicy*: enables the feature
- *autoExportCIDRs*: defines the address blocks to use (optional parameter)

## A. Create 2 new backends

The difference between both files lies in the *autoExportCIDRs* parameter, one has it while the other one does not.

```bash
$ kubectl create -n trident -f backend_with_CIDR.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-export-with-cidr created
$ kubectl create -n trident -f backend_without_CIDR.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-export-without-cidr created
```

## B. Check the export policies

Now, retrieve the IP adresses of all nodes of the cluster:

```bash
$ kubectl get nodes -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
```

Let's see how that translates in ONTAP. Open a new Putty session on 'cluster1', using admin/Netapp1!  
What export policies do we see:

```bash
cluster1::> export-policy show -vserver nfs_svm
Vserver          Policy Name
---------------  -------------------
nfs_svm          default
nfs_svm          trident-41774489-e1fe-42da-beae-5c0bd7f1ec36
nfs_svm          trident-e592606a-bf7d-4196-9d48-a732108e3ef9
3 entries were displayed.
```

The _default_ policy is always present, while the 2 other ones where dynamically created by Trident.  
Notice that the name of the policy contains the UUID of the Trident Backend.  

Now, let's look at the rule set by Trident for the backend _Export_with_CIDR_:  

```bash
cluster1::> export-policy rule show -vserver nfs_svm -policyname trident-e592606a-bf7d-4196-9d48-a732108e3ef9
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             1       nfs      192.168.0.61          any
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             2       nfs      192.168.0.62          any
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             3       nfs      192.168.0.63          any
3 entries were displayed.
```

You can see that there is a rule for every single node present in the cluster. No other host will be able to mount a resource present on this tenant, unless an admin manually adds more rules.  

Then, let's look at the rule set by Trident for the backend _Export_without_CIDR_:

```bash
cluster1::> export-policy rule show -vserver nfs_svm -policyname trident-41774489-e1fe-42da-beae-5c0bd7f1ec36
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nfs_svm      trident-41774489-e1fe-42da-beae-5c0bd7f1ec36
                             1       nfs      172.17.0.1,           any
                                              192.168.0.61,
                                              192.168.24.0
nfs_svm      trident-41774489-e1fe-42da-beae-5c0bd7f1ec36
                             2       nfs      172.17.0.1,           any
                                              192.168.0.62,
                                              192.168.24.192
nfs_svm      trident-41774489-e1fe-42da-beae-5c0bd7f1ec36
                             3       nfs      172.17.0.1,           any
                                              192.168.0.63,
                                              192.168.24.64
3 entries were displayed.
```

Notice the difference?  
Before creating the rules, Trident looked at all the unicast IP addresses on each node & used them on the storage backend.  

Also, as stated in the documentation, you must ensure that the root junction in your SVM has a pre-created export policy with an export rule that permits the node CIDR block (such as the *default* export policy). All volumes created by Trident are mounted under the root junction.  
Let's look at what we have in the LabOnDemand

```bash
cluster1::> export-policy rule show -vserver nfs_svm -policyname default
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nfs_svm      default         1       nfs      192.168.0.0/24        any
```

There you go, now, all applications created with these backends are going to have access to storage, while adding an extra level of security.

## C. More fun to prove my point

Let's see what happens if you add a new node to the cluster.
Once you are done with the [Addenda01](../../Addendum/Addenda01), you should have:

```bash
$ kubectl get nodes --watch
NAME    STATUS   ROLES    AGE   VERSION
rhel1   Ready    <none>   87d   v1.18.6
rhel2   Ready    <none>   87d   v1.18.6
rhel3   Ready    master   87d   v1.18.6
rhel4   Ready    <none>   72s   v1.18.6

$ kubectl get nodes -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
rhel4   192.168.0.64
```

By definition, Trident should have dynamically added a new entry in the export-policy:

```bash
cluster1::> export-policy rule show -vserver nfs_svm -policyname trident-e592606a-bf7d-4196-9d48-a732108e3ef9
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             1       nfs      192.168.0.61          any
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             2       nfs      192.168.0.62          any
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             3       nfs      192.168.0.63          any
nfs_svm      trident-e592606a-bf7d-4196-9d48-a732108e3ef9
                             4       nfs      192.168.0.64          any
4 entries were displayed.
```

Tadaaaa !

## D. Finally some optional cleanup

```bash
$ kubectl delete -n trident tbc backend-tbc-ontap-export-with-cidr
tridentbackendconfig.trident.netapp.io "backend-tbc-ontap-export-with-cidr" deleted
$ kubectl delete -n trident tbc backend-tbc-ontap-export-without-cidr
tridentbackendconfig.trident.netapp.io "backend-tbc-ontap-export-without-cidr" deleted
```

## E. What's next

You can now move on to:

- [Scenario13](../../Scenario13): CSI Snapshots Management

Maybe you could learn something in the different [addenda](https://github.com/YvosOnTheHub/LabNetApp)?
Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
