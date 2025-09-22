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

Trident 25.02 switched to **per-volume export policies management**, to bring more security and reduce to the minimum the rules assigned to a volume.  

Let's first retrieve the IP addresses of all nodes of the cluster:  
```bash
$ kubectl get nodes -o=custom-columns=NODE:.metadata.name,IP:.status.addresses[0].address
NODE    IP
rhel1   192.168.0.61
rhel2   192.168.0.62
rhel3   192.168.0.63
win1    192.168.0.72
win2    192.168.0.73
```

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario12_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario12_pull_images.sh
```

## A. Dynamic Export policies with ONTAP-NAS

Dynamic export policy management is enabled with 2 parameters (_autoExportCIDRs_ is optional):  
```yaml
  autoExportCIDRs:
  - 192.168.0.0/24
  autoExportPolicy: true
```
The _autoExportCIDRs_ parameter indicates Trident in which subnets look on the worker nodes to create the export policies.  
The backend _BackendForNFS_ is already equiped with that configuration.  

In order to see how this feature works, let's create an application with a PVC configured against the storage class corresponding to our backend:  
```bash
$ kubectl create -f busybox-ontap-nas-cidr.yaml
namespace/scenario12 created
persistentvolumeclaim/mydata created
deployment.apps/busybox created
```
Let's wait for the app to be ready:  
```bash
$ kubectl get -n scenario12 pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-5594d541-e81d-4588-8767-24b28b2b034a   1Gi        RWX            storage-class-nfs   <unset>                 51s
$ kubectl get -n scenario12 po -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
busybox-8547d6bf5c-5b7rr   1/1     Running   0          62s   192.168.26.12   rhel1   <none>           <none>
```
As you can see the Busybox pod runs on the host _rhel1_.  
Let's quickly retrieve the name of the volume created in ONTAP:  
```bash
$ kubectl get pv $(kubectl get pvc mydata -n scenario12 -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}{"\n"}'
trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
```
What configuration did Trident apply to ONTAP? Open a new Putty session on 'cluster1', using admin/Netapp1, to find out!  
```bash
cluster1::> export-policy show -vserver nassvm
Vserver          Policy Name
---------------  -------------------
nassvm           default
nassvm           trident_empty
nassvm           trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
3 entries were displayed.

cluster1::> export-policy rule show -vserver nassvm -policyname trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
                             1       nfs      192.168.0.61          any

cluster1::> vol show -vserver nassvm -volume trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a -fields policy
vserver volume                                           policy
------- ------------------------------------------------ ------------------------------------------------
nassvm  trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
```
You can see 2 things:
- Trident created a new Export Policy with the same name as its corresponding ONTAP volume
- This policy only contains one rule with the IP Address of the worker node where the pod is mounting the volume. 

What happens if we scale up our application? Let's find out:  
```bash
$ kubectl scale -n scenario12 deploy busybox --replicas=2
deployment.apps/busybox scaled

$ kubectl get -n scenario12 po -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
busybox-8547d6bf5c-5b7rr   1/1     Running   0          10m   192.168.26.12    rhel1   <none>           <none>
busybox-8547d6bf5c-mk5sr   1/1     Running   0          20s   192.168.25.104   rhel3   <none>           <none>
```
Our app now has 2 pods mounting the same PVC, running on different nodes.  
Let's check in ONTAP what we can find:  
```bash
cluster1::> export-policy show -vserver nassvm
Vserver          Policy Name
---------------  -------------------
nassvm           default
nassvm           trident_empty
nassvm           trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
3 entries were displayed.

cluster1::> export-policy rule show -vserver nassvm -policyname trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
                             1       nfs      192.168.0.61          any
nassvm       trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
                             2       nfs      192.168.0.63          any
2 entries were displayed.
```
Trident dynamically added a new rule to the export policy associated to our volume, allowing it to be mounted on both _rhel1_ & _rhel3_.  

Now let's imagine you want the pods of that app to only run on the remaining node (_rhel2_), you can also expect Trident to reflect that in the export policy.  
We can apply that modification by patching the deployment:  
```bash
$ kubectl -n scenario12 patch deployment busybox --type='merge' \
  -p '{"spec": {"template": {"spec": {"nodeSelector": {"kubernetes.io/hostname": "rhel2"}}}}}'
deployment.apps/busybox patched

$ kubectl get -n scenario12 po -o wide
NAME                      READY   STATUS    RESTARTS   AGE    IP               NODE    NOMINATED NODE   READINESS GATES
busybox-df99b997d-gkltg   1/1     Running   0          117s   192.168.28.123   rhel2   <none>           <none>
busybox-df99b997d-vbkkl   1/1     Running   0          2m5s   192.168.28.126   rhel2   <none>           <none>

cluster1::> export-policy rule show -vserver nassvm -policyname trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident_pvc_5594d541_e81d_4588_8767_24b28b2b034a
                             3       nfs      192.168.0.62          any
```
There you go, the export policy only contains the IP address of _rhel2_.  

Before proceeding, some optional clean up to do:  
```bash
kubectl delete ns scenario12
```

## B. Dynamic Export policies with ONTAP-NAS-ECONOMY

We have seen the behaviour of that feature with the ONTAP-NAS driver.  
How does it work with the Trident driver ONTAP-NAS-ECONOMY?  

We first need to create a new backend for this chapter:  
```bash
$ kubectl create -f backend-ontap-nas-eco-cidr.yaml
tridentbackendconfig.trident.netapp.io/backend-cidr-eco created
storageclass.storage.k8s.io/cidr-nas-economy created

$ kubectl get tbc -n trident backend-cidr-eco
NAME               BACKEND NAME           BACKEND UUID                           PHASE   STATUS
backend-cidr-eco   BackendForNFSCIDREco   0dcbf1f0-9644-4b3e-80cb-a6c0df16131d   Bound   Success
```
Keep the UUID in mind for a new seconds.  
Once the backend is present, you can immediately see 2 new export policies:  
```bash
cluster1::> export-policy show -vserver nassvm
Vserver          Policy Name
---------------  -------------------
nassvm           default
nassvm           trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d
nassvm           trident_empty
nassvm           trident_qtree_pool_export_policy
4 entries were displayed.
```
Notice that an export policy (empty for now) is namesd after the UUID of the corresponding backend (_0dcbf1f0-9644-4b3e-80cb-a6c0df16131d_), which makes it easy for monitoring or debugging.  
This is the export policy used by the _pool_ hosting the _PVC_ (ie the _FlexVol_ that owns the _qtrees_):  
```bash
cluster1::> export-policy rule show -vserver nassvm -policyname trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d
There are no entries matching your query.
```

What happens when we create new applications against this backend.  
To show case the various levels, let's create 2 applications, the first one will run on the node _rhel1_ and the other one on node _rhel2_.  
```bash
$ kubectl create -f busybox-ontap-nas-eco-1.yaml -f busybox-ontap-nas-eco-2.yaml
namespace/scenario12-1 created
persistentvolumeclaim/mydata created
deployment.apps/busybox created
namespace/scenario12-2 created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n scenario12-1 pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-e0e8e88a-0dbc-4f3e-8857-1911fe1032b1   1Gi        RWX            cidr-nas-economy    <unset>                 20s

$ kubectl get -n scenario12-1 pod -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
busybox-7687c65496-pjslr   1/1     Running   0          25s   192.168.26.16   rhel1   <none>           <none>

$ kubectl get -n scenario12-2 pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-1a85dbce-4b20-4073-9fc9-796540b361e3   1Gi        RWX            cidr-nas-economy    <unset>                 30s

$ kubectl get -n scenario12-2 pod -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
busybox-6d947ff8bc-hxsnw   1/1     Running   0          35s   192.168.28.125   rhel2   <none>           <none>
```
We can see that the pods are running on the expected hosts. Also, since this is the first time qtrees are created, a new _pool_ (an ONTAP flexvol) will appear, as well as new export policies:  
```bash
cluster1::> vol show -vserver nassvm
Vserver   Volume       Aggregate    State      Type       Size  Available Used%
--------- ------------ ------------ ---------- ---- ---------- ---------- -----
nassvm    nassvm_root  aggr1        online     RW         20MB    17.39MB    8%
nassvm    trident_qtree_pool_trident_DKDGYGXVNY
                       aggr1        online     RW          1GB     1023MB    0%
2 entries were displayed.

cluster1::> export-policy show -vserver nassvm
Vserver          Policy Name
---------------  -------------------
nassvm           default
nassvm           trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d
nassvm           trident_empty
nassvm           trident_pvc_1a85dbce_4b20_4073_9fc9_796540b361e3
nassvm           trident_pvc_e0e8e88a_0dbc_4f3e_8857_1911fe1032b1
nassvm           trident_qtree_pool_export_policy
6 entries were displayed.
```
Let's check what export policies are currently in use, first for the pool:  
```bash
cluster1::> vol show -vserver nassvm -volume trident_qtree_pool_trident_DKDGYGXVNY -fields policy
vserver volume                                policy
------- ------------------------------------- --------------------------------------------
nassvm  trident_qtree_pool_trident_DKDGYGXVNY trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d

cluster1::> export-policy rule show -vserver nassvm -policyname trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d
                             1       nfs      192.168.0.61          any
nassvm       trident-0dcbf1f0-9644-4b3e-80cb-a6c0df16131d
                             2       nfs      192.168.0.62          any
2 entries were displayed.
```
As you can see there 2 rules for the pool, simply because there are 2 qtrees in that pool, objects mounted on different nodes.  
What about the first PVC (ie the first qtree):  
```bash
cluster1::> qtree show -vserver nassvm -volume trident_qtree_pool_trident_DKDGYGXVNY -qtree trident_pvc_e0e8e88a_0dbc_4f3e_8857_1911fe1032b1 -fields export-policy
vserver volume                                qtree                                            export-policy
------- ------------------------------------- ------------------------------------------------ ------------------------------------------------
nassvm  trident_qtree_pool_trident_DKDGYGXVNY trident_pvc_e0e8e88a_0dbc_4f3e_8857_1911fe1032b1 trident_pvc_e0e8e88a_0dbc_4f3e_8857_1911fe1032b1

cluster1::> export-policy rule show -vserver nassvm -policyname trident_pvc_e0e8e88a_0dbc_4f3e_8857_1911fe1032b1
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident_pvc_e0e8e88a_0dbc_4f3e_8857_1911fe1032b1
                             1       nfs      192.168.0.61          any
```

Followed by the second PVC:  
```bash
cluster1::> qtree show -vserver nassvm -volume trident_qtree_pool_trident_DKDGYGXVNY -qtree trident_pvc_1a85dbce_4b20_4073_9fc9_796540b361e3 -fields export-policy
vserver volume                                qtree                                            export-policy
------- ------------------------------------- ------------------------------------------------ ------------------------------------------------
nassvm  trident_qtree_pool_trident_DKDGYGXVNY trident_pvc_1a85dbce_4b20_4073_9fc9_796540b361e3 trident_pvc_1a85dbce_4b20_4073_9fc9_796540b361e3


cluster1::> export-policy rule show -vserver nassvm -policyname trident_pvc_1a85dbce_4b20_4073_9fc9_796540b361e3
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident_pvc_1a85dbce_4b20_4073_9fc9_796540b361e3
                             1       nfs      192.168.0.62          any
```
Notice that each qtree rule contains only one IP address, corresponding to the worker node hosting the pod mounting the PVC.  

Before proceeding, some optional clean up to do:  
```bash
kubectl delete ns scenario12-1 scenario12-2
kubectl delete tbc -n trident backend-cidr-eco
kubectl delete sc cidr-nas-economy
```

## C. Dynamic Export policies with ONTAP-NAS without CIDR specification

In the last part of this chapter, we will configure a new backend with the feature enabled, but without specifying the CIDR:  
```bash
$ kubectl create -f backend-ontap-nas-no-cidr.yaml
tridentbackendconfig.trident.netapp.io/backend-nfs-no-cidr created
storageclass.storage.k8s.io/nfs-no-cidr created
```
Let's create an application using that backend:  
```bash
$ kubectl create -f busybox-ontap-nas-nocidr.yaml
namespace/scenario12-3 created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n scenario12-3 po -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
busybox-8547d6bf5c-hxmdj   1/1     Running   0          86s   192.168.26.19   rhel1   <none>           <none>

$ kubectl get -n scenario12-3 pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-4a81db81-5ba3-479c-9624-5147be0e30ab   1Gi        RWX            nfs-no-cidr    <unset>                 90s
```
Time to check the content in ONTAP:  
```bash
luster1::> export-policy show -vserver nassvm
Vserver          Policy Name
---------------  -------------------
nassvm           default
nassvm           trident_empty
nassvm           trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab
3 entries were displayed.

cluster1::> export-policy rule show -vserver nassvm -policyname trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab
                             1       nfs      192.168.0.61          any
nassvm       trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab
                             2       nfs      192.168.26.0          any
2 entries were displayed.
```
Before creating the rules, Trident looked at all the unicast IP addresses on each node & used them on the storage backend.  
As you can see, this time the export policy associated to the PVC contains 2 rules, from 2 different subnets, because we haven't specified which one to use to mount volumes:  
- the subnet connected to the storage (192.168.0.0/24). 
- the subnet used for pod to pod communication via VXLAN and set in Calico (192.168.24.0/21)

Looking further in ONTAP, you will find that the address mounting the volume is indeed 192.168.0.61:  
```bash
cluster1::> nfs connected-clients show  -vserver nassvm -volume trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab

     Node: cluster1-01
  Vserver: nassvm
  Data-Ip: 192.168.0.131
Client-Ip      Protocol Volume    Policy   Idle-Time    Local-Reqs Remote-Reqs
-------------- -------- --------- -------- ------------ ---------- ----------
Trunking
-------
192.168.0.61   nfs4.2   trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab
                                  trident_pvc_4a81db81_5ba3_479c_9624_5147be0e30ab
                                           1m 21s       21       0     false
```

Last clean up to do:  
```bash
kubectl delete ns scenario12-3
kubectl delete tbc -n trident backend-nfs-no-cidr
kubectl delete sc nfs-no-cidr
```

## D. SVM Root export policy

As stated in the documentation, you must ensure that the root junction in your SVM has a pre-created export policy with an export rule that permits the node CIDR block (such as the *default* export policy). All volumes created by Trident are mounted under the root junction.  
Let's look at what we have in the LabOnDemand:  
```bash
cluster1::> export-policy rule show -vserver nassvm -policyname default
             Policy          Rule    Access   Client                RO
Vserver      Name            Index   Protocol Match                 Rule
------------ --------------- ------  -------- --------------------- ---------
nassvm       default         1       nfs      0.0.0.0/24            any
```

There you go, now, all applications created with these backends are going to have access to storage, while adding an extra level of security.


## E. What's next

You can now move on to:  
- [Scenario13](../Scenario13): CSI Snapshots Management

Maybe you could learn something in the different [addenda](https://github.com/YvosOnTheHub/LabNetApp)?
Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
