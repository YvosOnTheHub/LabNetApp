#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

**GOAL:**  
Trident 20.04 introduced a new way to manage its lifecycle: Operators.  
For now, this method is only intended for green field environments. We will then first need to delete & clean up the current Trident objects


## A. Cleanup up Trident & Download the new version

*tridenctlctl* is the tool shipped with Trident in order to interact with it.  
It is also recommended to install Trident in its own namespace (usually called *trident*)
```
# tridentctl -n trident version 
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 19.07.1        | 19.07.1        |
+----------------+----------------+
```
In this example, we will remove all objects linked to Trident 19.07.1.
I will consider that there is no PVC configured with Trident.  

First, let's remove all current Kubernetes storage classes & Tridents' backends (this is optional)
```
# kubectl delete sc --all
# tridentctl -n trident delete backend --all
```
Then, delete the CRD deployed & used by Trident.  

:mag:  
*A* **resource** *is an endpoint in the Kubernetes API that stores a collection of API objects of a certain kind; for example, the built-in pods resource contains a collection of Pod objects.*  
*A* **custom resource** *is an extension of the Kubernetes API that is not necessarily available in a default Kubernetes installation. It represents a customization of a particular Kubernetes installation. However, many core Kubernetes functions are now built using custom resources, making Kubernetes more modular.*  
:mag_right:  
```
# tridentctl -n trident obliviate crd --yesireallymeanit
INFO Resources not present.                        CRD=tridentversions.trident.netapp.io
INFO Resources not present.                        CRD=tridentbackends.trident.netapp.io
INFO Resources not present.                        CRD=tridentstorageclasses.trident.netapp.io
INFO Resources not present.                        CRD=tridentvolumes.trident.netapp.io
INFO Resources not present.                        CRD=tridentnodes.trident.netapp.io
INFO Resources not present.                        CRD=tridenttransactions.trident.netapp.io
INFO Resources not present.                        CRD=tridentsnapshots.trident.netapp.io
INFO CRD deleted.                                  CRD=tridentversions.trident.netapp.io
INFO CRD deleted.                                  CRD=tridentbackends.trident.netapp.io
INFO CRD deleted.                                  CRD=tridentstorageclasses.trident.netapp.io
INFO CRD deleted.                                  CRD=tridentvolumes.trident.netapp.io
INFO CRD deleted.                                  CRD=tridentnodes.trident.netapp.io
INFO CRD deleted.                                  CRD=tridenttransactions.trident.netapp.io
INFO CRD deleted.                                  CRD=tridentsnapshots.trident.netapp.io
INFO Reset Trident's CRD state.
```
You can now uninstall Trident:  
```
# tridentctl -n trident uninstall
INFO Deleted Trident deployment.
INFO Deleted Trident daemonset.
INFO Deleted Trident service.
INFO Deleted Trident secret.
INFO Deleted cluster role binding.
INFO Deleted cluster role.
INFO Deleted service account.
INFO Deleted pod security policy.                  podSecurityPolicy=tridentpods
INFO Deleted csidriver custom resource.            CSIDriver=csi.trident.netapp.io
INFO The uninstaller did not delete Trident's namespace in case it is going to be reused.
INFO Trident uninstallation succeeded.

# kubectl delete namespace trident
namespace "trident" deleted
```

Download the version you would like to install
```
# cd
# mv trident-installer/ trident-installer_19.07
# wget https://github.com/NetApp/trident/releases/download/v20.04.0/trident-installer-20.04.0.tar.gz
# tar -xf trident-installer-20.04.0.tar.gz
```
Finally, remove the CRD related to the Snapshot alpha feature.
```
# tridentctl -n trident obliviate alpha-snapshot-crd
INFO CRD deleted.                                  CRD=volumesnapshotclasses.snapshot.storage.k8s.io
INFO CRD deleted.                                  CRD=volumesnapshotcontents.snapshot.storage.k8s.io
INFO CRD deleted.                                  CRD=volumesnapshots.snapshot.storage.k8s.io
```
You have now a clean environment !

## C. Install Trident

With Trident 20.04, there are new objects in the picture:
- Trident Operator, which will dynamically manage Trident's resources, automate setup, fix broken elements
- Trident Provisioner, which is a Custom Resource, and is the object you will use to interact with the Trident Operator for specific tasks (upgrades, enable/disable Trident options, such as _debug_ mode, uninstall)  

You can visualize the *Operator* as being the *Control Tower*, and the *Provisioner* as being the *Mailbox* in which you post configuration requests.
Other operations, such as Backend management or logs display are currently still managed by Tridentctl


OK, now let's first check the version of Kubernetes you are using:
```
# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.15.3
rhel2   Ready    <none>   214d   v1.15.3
rhel3   Ready    master   214d   v1.15.3
```
The CRD object was promoted to GA with Kubernetes 1.16.  
Depending on the current version of Kubernetes you are running, you will need to use one of the 2 following commands in order to install the Trident Provsioner CRD.
```
# kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentprovisioners_crd_pre1.16.yaml
customresourcedefinition.apiextensions.k8s.io/tridentprovisioners.trident.netapp.io created
```
OR
```
# kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentprovisioners_crd_post1.16.yaml
customresourcedefinition.apiextensions.k8s.io/tridentprovisioners.trident.netapp.io created
```
You will end up with a brand new CRD:
```
# kubectl get crd
NAME                                    CREATED AT
tridentprovisioners.trident.netapp.io   2020-05-06T08:48:08Z
```
We can now deploy the Operator, as well as all the necessary resources that go along with it:
```
# kubectl create namespace trident
namespace/trident created

# kubectl create -f trident-installer/deploy/bundle.yaml
serviceaccount/trident-operator created
clusterrole.rbac.authorization.k8s.io/trident-operator created
clusterrolebinding.rbac.authorization.k8s.io/trident-operator created
deployment.apps/trident-operator created
podsecuritypolicy.policy/tridentoperatorpods created
```
Let's check that the Operator is up & running
```
# kubectl get all -n trident
NAME                                    READY   STATUS    RESTARTS   AGE
pod/trident-operator-78c5b7f97f-g6bnk   1/1     Running   0          24s

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trident-operator   1/1     1            1           24s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/trident-operator-78c5b7f97f   1         1         1       24s
```
OK, the operator is installed, as well as the provisioner CRD. Time to finally install Trident:
```
# kubectl create -f trident-installer/deploy/crds/tridentprovisioner_cr.yaml
tridentprovisioner.trident.netapp.io/trident created

# kubectl get tprov -n trident
NAME      AGE
trident   13s
```
Tadaaaaa !  


## D. Check the status  
After a few seconds, you should the status _installed_ in the provisioner CRD.
```
# kubectl describe tprov trident -n trident
Name:         trident
Namespace:    trident
Labels:       <none>
Annotations:  <none>
API Version:  trident.netapp.io/v1
Kind:         TridentProvisioner
Metadata:
  Creation Timestamp:  2020-05-04T09:54:22Z
  Generation:          1
  Resource Version:    474710
  Self Link:           /apis/trident.netapp.io/v1/namespaces/trident/tridentprovisioners/trident
  UID:                 2c8000f2-d4d8-4436-b449-0c0affbc6989
Spec:
  Debug:  true
Status:
  Message:  Trident installed
  Status:   Installed
  Version:  v20.04
Events:
  Type    Reason      Age   From                        Message
  ----    ------      ----  ----                        -------
  Normal  Installing  40s   trident-operator.netapp.io  Installing Trident
  Normal  Installed   9s    trident-operator.netapp.io  Trident installed

# tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 20.04.0        | 20.04.0        |
+----------------+----------------+

# kubectl -n trident get tridentversions
NAME      VERSION
trident   20.04
```
The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://netapp-trident.readthedocs.io/en/stable-v20.04/kubernetes/operator-install.html#observing-the-status-of-the-operator  
  
If you just want to display part of the description, you can use a filter such as:
```
# kubectl describe tprov trident -n trident | grep Message: -A 3
  Message:  Trident installed
  Status:   Installed
  Version:  v20.04
```


## G. What's next

Now that Trident is installed, you can proceed with :  
- [Scenario02](../../Scenario02):  Installing Prometheus & incorporate Trident's metrics  
Or you can directly   
- [Scenario04](../../Scenario04):  Configure your first NAS backends & storage classes  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)