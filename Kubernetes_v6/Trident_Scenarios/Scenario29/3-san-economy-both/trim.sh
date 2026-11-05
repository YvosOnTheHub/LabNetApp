#!/bin/bash
# Ask the guest to UNMAP free blocks on one PVC.
# The storage class is not mounted with discard, so a delete and a trim stay separate.
# fstrim is in the BusyBox image. The FITRIM ioctl needs CAP_SYS_ADMIN, so this starts
# a short-lived pod that mounts the same claim on the node that already has it.
set -eu

NS=${1:?namespace}
APP=${2:?app label}
PVC=${3:?pvc name}

pod=$(kubectl get pod -n "$NS" -l app="$APP" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
node=$(kubectl get pod -n "$NS" "$pod" -o jsonpath='{.spec.nodeName}')

echo "trimming ${PVC} on ${node}"

kubectl delete pod -n "$NS" fstrim --ignore-not-found --wait=true >/dev/null

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fstrim
  namespace: ${NS}
spec:
  restartPolicy: Never
  nodeName: ${node}
  containers:
  - name: fstrim
    image: registry.demo.netapp.com/busybox:1.35.0
    imagePullPolicy: IfNotPresent
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
    command: ["fstrim", "-v", "/data"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: ${PVC}
EOF

if ! kubectl wait -n "$NS" --for=jsonpath='{.status.phase}'=Succeeded pod/fstrim --timeout=120s; then
  kubectl logs -n "$NS" fstrim || true
  kubectl describe pod -n "$NS" fstrim || true
  exit 1
fi
kubectl logs -n "$NS" fstrim
kubectl delete pod -n "$NS" fstrim --wait=false >/dev/null
