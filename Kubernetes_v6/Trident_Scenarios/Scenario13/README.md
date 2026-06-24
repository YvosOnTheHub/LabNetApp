#########################################################################################
# SCENARIO 13: Snapshots here & snapshots there, snapshot everywhere
#########################################################################################  

A snapshot is an IT industry wide term used to define a state of a system taken at a point in time.  
It can be used to rapidly restore data, create backups, clones, etc...  

If you have not yet upgraded the Snapshot controller, I would recommend to do so as some chapters require a new version (ex: Kubevirt VM templates, Volume Group Snapshot, ...). You can check the current version running the following:  
```bash
$ kubectl  -n kube-system get deploy snapshot-controller -ojsonpath='{.spec.template.spec.containers[0].image}'; echo
registry.k8s.io/sig-storage/snapshot-controller:v6.1.0
```
If you see the version displayed above (_v6.1.0_), run the following to upgrade the controller to v8 (or use the *vscontroller_install_8.sh* script in this folder):  
```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd?ref=v8.2.0 | kubectl apply -f -
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/snapshot-controller?ref=v8.2.0 | kubectl apply -f -
kubectl patch -n kube-system deploy snapshot-controller --type=json -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value":{"kubernetes.io/os":"linux"}}]'
```

In this lab, we are going to cover multiple types of snapshots, which are actually tied together:
- [CSI Snapshots](1_CSI_Snapshots): Snapshots in Kubernetes managed in the user namespace  
- [CSI Volume Group Snapshots](2_CSI_VolumeGroupSnapshots): Snapshots of multiple volumes in Kubernetes  
- [ONTAP Snapshots](3_ONTAP_Snapshots): Snapshots taken in the storage backend & access in Kubernetes