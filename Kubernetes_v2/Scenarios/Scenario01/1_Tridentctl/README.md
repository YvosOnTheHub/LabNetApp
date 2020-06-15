#########################################################################################
# SCENARIO 1: Trident install/upgrade with tridenctl
#########################################################################################

**GOAL:**  
This scenario is intended to see how easy it is to upgrade Trident with Tridentctl
The examples below will guide you in performing an upgrade from 19.07.1 to 20.04


## A. Check the current version

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

Trident 19.07 introduced the use of Kubernetes CRD in order to store its own metadata.
That way, when you apply your own Kubernetes protection & backup policies, Trident's metadata are by design included.  

:mag:  
*A* **resource** *is an endpoint in the Kubernetes API that stores a collection of API objects of a certain kind; for example, the built-in pods resource contains a collection of Pod objects.*  
*A* **custom resource** *is an extension of the Kubernetes API that is not necessarily available in a default Kubernetes installation. It represents a customization of a particular Kubernetes installation. However, many core Kubernetes functions are now built using custom resources, making Kubernetes more modular.*  
:mag_right:  

```
# kubectl get crd
NAME                                             CREATED AT
tridentbackends.trident.netapp.io                2019-09-09T04:25:30Z
tridentnodes.trident.netapp.io                   2019-09-09T04:25:30Z
tridentsnapshots.trident.netapp.io               2019-09-09T04:25:30Z
tridentstorageclasses.trident.netapp.io          2019-09-09T04:25:30Z
tridenttransactions.trident.netapp.io            2019-09-09T04:25:30Z
tridentversions.trident.netapp.io                2019-09-09T04:25:30Z
tridentvolumes.trident.netapp.io                 2019-09-09T04:25:30Z
volumesnapshotclasses.snapshot.storage.k8s.io    2019-09-09T04:25:33Z
volumesnapshotcontents.snapshot.storage.k8s.io   2019-09-09T04:25:33Z
volumesnapshots.snapshot.storage.k8s.io          2019-09-09T04:25:33Z

# kubectl -n trident get tridentversions
NAME      VERSION
trident   19.07.1

# kubectl -n trident get tridentbackends
NAME        BACKEND               BACKEND UUID
tbe-f26zw   BackendForSolidFire   d9d6bef6-eef9-4ff0-b5c8-c69d048b739e
tbe-vs95d   BackendForNAS         e098abb8-8e16-4b4f-a4bc-a6c9557b39b1
```
As you can see, some backends are alrady configured.
A backend is composed of a specific Trident driver & different parameters that will tell Tell where to connect & how.


## B. Uninstall the current version

If you keep the default parameters during the installation process, Trident's CRD will remain as is.
That allows a seamsless upgrade of Trident

```
# tridentctl -n trident uninstall
INFO Created installer service account.            serviceaccount=trident-installer
INFO Created installer cluster role.               clusterrole=trident-installer
INFO Created installer cluster role binding.       clusterrolebinding=trident-installer
INFO Created uninstaller pod.                      pod=trident-installer
INFO Waiting for Trident installer pod to start.
INFO Trident installer pod started.                namespace=trident pod=trident-installer
INFO Deleted Trident deployment.
INFO Deleted Trident daemonset.
INFO Deleted Trident service.
INFO Deleted Trident secret.
INFO Deleted cluster role binding.
INFO Deleted cluster role.
INFO Deleted service account.
INFO The uninstaller did not delete Trident's namespace in case it is going to be reused.
INFO Trident uninstallation succeeded.
INFO Waiting for Trident installer pod to finish.
INFO Trident installer pod finished.               namespace=trident pod=trident-installer
INFO Deleted uninstaller pod.                      pod=trident-installer
INFO Deleted installer cluster role binding.
INFO Deleted installer cluster role.
INFO Deleted installer service account.
```

## C. Download the version you would like to install
```
# cd
# mv trident-installer/ trident-installer_19.07
# wget https://github.com/NetApp/trident/releases/download/v20.04.0/trident-installer-20.04.0.tar.gz
# tar -xf trident-installer-20.04.0.tar.gz
```

## D. Install the new version

Before moving to the installation, there is some extra cleanup to do.  
Trident 19.07.1 introduced the support of the CSI On-Demand Snapshots Alpha with Kubernetes 1.15.
This feature has been promoted to Beta with Kubernetes 1.17, which has been supported since Trident 20.01.  
This promotion also came with a change of architecture, and the removal of Trident's support for the alpha version.
The *snapshot* CRD then need to be removed with the following command
```
# tridentctl -n trident obliviate alpha-snapshot-crd
INFO CRD deleted.                                  CRD=volumesnapshotclasses.snapshot.storage.k8s.io
INFO CRD deleted.                                  CRD=volumesnapshotcontents.snapshot.storage.k8s.io
INFO CRD deleted.                                  CRD=volumesnapshots.snapshot.storage.k8s.io
```
(For some reason, you sometimes need to run this command twice.)  
More information about this here: https://netapp.io/2020/01/30/alpha-to-beta-snapshots/

Now, let's process with the new version of Trident
```
# tridentctl -n trident install 
INFO Starting Trident installation.                namespace=trident
INFO Created service account.
INFO Created cluster role.
INFO Created cluster role binding.
INFO Created Trident pod security policy.
INFO Added finalizers to custom resource definitions.
INFO Created Trident service.
INFO Created Trident secret.
INFO Created Trident deployment.
INFO Created Trident daemonset.
INFO Waiting for Trident pod to start.
INFO Trident pod started.                          namespace=trident pod=trident-csi-6b778f79bb-xnjws
INFO Waiting for Trident REST interface.
INFO Trident REST interface is up.                 version=20.04
INFO Trident installation succeeded.
```

## E. Check the current version
```
# tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 20.04.0        | 20.04.0        |
+----------------+----------------+

# kubectl -n trident get tridentversions
NAME      VERSION
trident   20.04

# kubectl -n trident get tridentbackends
NAME        BACKEND               BACKEND UUID
tbe-f26zw   BackendForSolidFire   d9d6bef6-eef9-4ff0-b5c8-c69d048b739e
tbe-vs95d   BackendForNAS         e098abb8-8e16-4b4f-a4bc-a6c9557b39b1
```
As you can see, the backends are still present, nothing has been deleted in terms of Trident configuration.

## F. Cleanup

As this environment is already configured with different objects (backends, storage classes ...) and it order to get the best out of these learning scenarios, I would recommended to delete these objects

```
# kubectl delete sc --all
# tridentctl -n trident delete backend --all
```

## G. What's next

Now that Trident is installed, you can proceed with :  
- [Scenario02](../../Scenario02):  Installing Prometheus & incorporate Trident's metrics  
Or you can directly go to  
- [Scenario04](../../Scenario04):  Configure your first NAS backends & storage classes  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)