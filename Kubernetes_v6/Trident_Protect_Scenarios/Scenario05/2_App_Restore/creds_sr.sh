export KUBECONFIG=/root/.kube/config

kubectl create ns tpsc05busyboxsr

cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bbox-rw
  namespace: tpsc05busyboxsr
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["snapshots.storage.k8S.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-rw-binding
  namespace: tpsc05busyboxsr
subjects:
- kind: ServiceAccount
  name: bbox-user
  namespace: tpsc05busybox
roleRef:
  kind: Role
  name: bbox-rw
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-protection-binding
  namespace: tpsc05busyboxsr
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: trident-protect-tenant-cluster-role
subjects:
- kind: ServiceAccount
  name: bbox-user
  namespace: tpsc05busybox
EOF

# kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:bbox-user get pods -n tpsc05busyboxsr
# kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:bbox-user get snapshotrestores -n tpsc05busyboxsr

export KUBECONFIG=/root/.kube/tpsc05-rhel3