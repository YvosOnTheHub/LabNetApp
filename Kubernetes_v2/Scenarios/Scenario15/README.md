#########################################################################################
# SCENARIO 15: Dynamic Export Policy Management
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

```
# tridentctl -n trident create backend -f backend-with-CIDR.json
+------------------+----------------+--------------------------------------+--------+---------+
|       NAME       | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+------------------+----------------+--------------------------------------+--------+---------+
| Export_with_CIDR | ontap-nas      | ebf1efb0-e8c6-457e-8e1a-827b1725ed9e | online |       0 |
+------------------+----------------+--------------------------------------+--------+---------+

# tridentctl -n trident create backend -f backend-without-CIDR.json
+---------------------+----------------+--------------------------------------+--------+---------+
|        NAME         | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+---------------------+----------------+--------------------------------------+--------+---------+
| Export_without_CIDR | ontap-nas      | f9683c16-e35c-4fea-b185-2e0d7eea0eb3 | online |       0 |
+---------------------+----------------+--------------------------------------+--------+---------+
```

## B. Check the export policies

Now, retrieve the IP adresses of all nodes of the cluster:
```
# kubectl get nodes -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
```
Let's see how that translate into ONTAP. Open a new Putty session on 'cluster1', using admin/Netapp1!  
What export policies do we see:
```
cluster1::> export-policy show
Vserver          Policy Name
---------------  -------------------
svm1             default
svm1             trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
svm1             trident-f9683c16-e35c-4fea-b185-2e0d7eea0eb3
3 entries were displayed.
```
The _default_ policy is always present, while the 2 other ones where dynamically created by Trident.  
Notice that the name of the policy contains the UUID of the Trident Backend.  

Now, let's look at the rule set by Trident for the backend _Export_with_CIDR_:  
```
cluster1::> export-policy rule show -vserver svm1 -policyname trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             1       nfs      192.168.0.62          any
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             2       nfs      192.168.0.61          any
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             3       nfs      192.168.0.63          any
3 entries were displayed.
```
You can see that there is a rule for every single node present in the cluster. No other host will be able to mount a resource present on this tenant, unless an admin manually adds more rules.  

Then, let's look at the rule set by Trident for the backend _Export_without_CIDR_: 
```
cluster1::> export-policy rule show -vserver svm1 -policyname trident-f9683c16-e35c-4fea-b185-2e0d7eea0eb3
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
svm1         trident-f9683c16-e35c-4fea-b185-2e0d7eea0eb3
                             1       nfs      10.44.0.0,172.17.0.1, any
                                              192.168.0.62
svm1         trident-f9683c16-e35c-4fea-b185-2e0d7eea0eb3
                             2       nfs      10.36.0.0,172.17.0.1, any
                                              192.168.0.61
svm1         trident-f9683c16-e35c-4fea-b185-2e0d7eea0eb3
                             3       nfs      10.32.0.1,172.17.0.1, any
                                              192.168.0.63
3 entries were displayed.
```
Notice the difference?  
Before creating the rules, Trident looked at all the unicast IP addresses on each node & used them on the storage backend.  

Also, as stated in the documentation, you must ensure that the root junction in your SVM has a pre-created export policy with an export rule that permits the node CIDR block (such as the *default* export policy). All volumes created by Trident are mounted under the root junction.  
Let's look at what we have in the LabOnDemand
```
cluster1::> export-policy rule show -vserver svm1 -policyname default
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
svm1         default         1       nfs      0.0.0.0/0             any
```
There you go, now, all applications created with these backends are going to have access to storage, while adding an extra level of security.


## C. More fun to prove my point

Let's see what happens if you add a new node to the cluster.
Once you are done with the [Addenda01](../../Addendum/Addenda01), you should have:
```
# kubectl get nodes --watch
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   240d   v1.15.3
rhel2   Ready    <none>   240d   v1.15.3
rhel3   Ready    master   240d   v1.15.3
rhel4   Ready    <none>   72s    v1.15.3

# kubectl get nodes -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
rhel4   192.168.0.64
```
By definition, Trident should have dynamically added a new entry in the export-policy:
```
cluster1::> export-policy rule show -vserver svm1 -policyname trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             1       nfs      192.168.0.62          any
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             2       nfs      192.168.0.61          any
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             3       nfs      192.168.0.63          any
svm1         trident-ebf1efb0-e8c6-457e-8e1a-827b1725ed9e
                             4       nfs      192.168.0.64          any
4 entries were displayed.
```
Tadaaaa !

## D. Finally some optional cleanup.
```
# tridentctl -n trident delete backend Export_with_CIDR
# tridentctl -n trident delete backend Export_without_CIDR
```

## E. What's next

You may have gone through all scenarios.  
Maybe you could learn something in the different [addenda](../../)?
