VOLPATH=$(kubectl get tmr busybox-mirror -n sc24busybox -o jsonpath='{.status.conditions[0].localVolumeHandle}')

kubectl --kubeconfig=/root/.kube/config_rhel5 create ns sc24busybox

cat << EOF | kubectl apply --kubeconfig=/root/.kube/config_rhel5 -f -
apiVersion: trident.netapp.io/v1
kind: TridentMirrorRelationship
metadata:
  name: busybox-mirror
  namespace: sc24busybox
spec:
  state: established
  volumeMappings:
  - localPVCName: mydata
    remoteVolumeHandle: "$VOLPATH"
EOF