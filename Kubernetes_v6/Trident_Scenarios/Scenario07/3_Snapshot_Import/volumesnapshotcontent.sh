GHOSTPV=$(kubectl get pv $( kubectl get pvc blog-content-import -n ghost -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.metadata.name}')

cat << EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotContent
metadata:
  name: vsc-import
  annotations:
    trident.netapp.io/internalSnapshotName: snap-to-import
spec:
  deletionPolicy: Delete
  driver: csi.trident.netapp.io
  source:
    snapshotHandle: $GHOSTPV/vsc-import
  volumeSnapshotRef:
    name: volumesnap
    namespace: ghost
EOF