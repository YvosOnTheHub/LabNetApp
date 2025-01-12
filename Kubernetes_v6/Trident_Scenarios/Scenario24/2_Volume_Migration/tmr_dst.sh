VOLPATH=$(kubectl get tmr busybox-mirror-src -n sc24busybox -o jsonpath='{.status.conditions[0].localVolumeHandle}')

cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentMirrorRelationship
metadata:
  name: busybox-mirror-dst
  namespace: sc24busybox
spec:
  state: established
  volumeMappings:
  - localPVCName: mydatadst
    remoteVolumeHandle: "$VOLPATH"
EOF