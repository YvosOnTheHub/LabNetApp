
echo
echo "##############################################################"
echo "# Delete existing snapshot controller and CRDs"
echo "##############################################################"
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl delete -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

echo
echo "##############################################################"
echo "# Apply snapshot controller and CRDs for v8.2"
echo "##############################################################"
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd?ref=v8.2.0 | kubectl apply -f -
kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/snapshot-controller?ref=v8.2.0 | kubectl apply -f -
kubectl patch -n kube-system deploy snapshot-controller --type=json -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value":{"kubernetes.io/os":"linux"}}]'


echo
echo "##############################################################"
echo "# Create VolumeSnapshotClass for Trident"
echo "##############################################################"
cat << EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snap-class
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: csi.trident.netapp.io
deletionPolicy: Delete
EOF