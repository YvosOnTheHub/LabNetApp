#########################################################################################
# SCENARIO 13: Kubernetes CSI Snapshots & PVC from Snapshot workflows
#########################################################################################

**GOAL:**  
Kubernetes 1.17 promoted [CSI Snapshots to Beta](https://kubernetes.io/blog/2019/12/09/kubernetes-1-17-feature-cis-volume-snapshot-beta/).  
This has been fully supported starting with Trident 20.01.1.  
(by the way, CSI Snapshots have been promoted GA with Kubernetes 1.20)

While snapshots can be used for many use cases, we will see here 2 different ones, which share the same beginning:

- Restore the snapshot in the current application
- Create a new POD which uses a PVC created from the snapshot

There is also a chapter that will show you the impact of deletion between PVC, Snapshots & Clones (spoiler alert: no impact).  

I would recommended checking that the CSI Snapshot feature is actually enabled on this platform.  

This [link](https://github.com/kubernetes-csi/external-snapshotter) is a good read if you want to know more details about installing the CSI Snapshotter.  
The **CRD** & **Snapshot-Controller** to enable this feature have already been installed in this cluster. Let's see what we find:

```bash
$ kubectl get crd | grep volumesnapshot
volumesnapshotclasses.snapshot.storage.k8s.io         2020-08-29T21:08:34Z
volumesnapshotcontents.snapshot.storage.k8s.io        2020-08-29T21:08:55Z
volumesnapshots.snapshot.storage.k8s.io               2020-08-29T21:09:13Z

$ kubectl get all -n snapshot-controller
NAME                        READY   STATUS    RESTARTS   AGE
pod/snapshot-controller-0   1/1     Running   0          20h

NAME                                   READY   AGE
statefulset.apps/snapshot-controller   1/1     27d
```

Aside from the 3 CRD & the Controller StatefulSet, the following objects have also been created during the installation of the CSI Snapshot feature:

- serviceaccount/snapshot-controller
- clusterrole.rbac.authorization.k8s.io/snapshot-controller-runner
- clusterrolebinding.rbac.authorization.k8s.io/snapshot-controller-role
- role.rbac.authorization.k8s.io/snapshot-controller-leaderelection
- rolebinding.rbac.authorization.k8s.io/snapshot-controller-leaderelection

Finally, you need to create a _VolumeSnapshotClass_ object that points to the Trident driver.

```bash
$ kubectl create -f sc-volumesnapshot.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class created

$ kubectl get volumesnapshotclass
NAME             DRIVER                  DELETIONPOLICY   AGE
csi-snap-class   csi.trident.netapp.io   Delete           3s
```

Note that the _deletionpolicy_ parameter could also be set to _Retain_.

The _volume snapshot_ feature is now ready to be tested.

You can move forward with one of the 2 following chapters:

[1.](1_Busybox) Simple snapshot managment with Busybox (all CLI)  
[2.](2_Ghost) More advanced usage of snapshots with Ghost (some GUI involved)
