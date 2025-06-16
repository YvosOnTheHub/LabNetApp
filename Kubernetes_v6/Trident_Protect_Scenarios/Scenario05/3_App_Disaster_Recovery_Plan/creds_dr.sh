export KUBECONFIG=/root/.kube/config
kubectl config use-context kub2-admin@kub2

kubectl create ns tpsc05busyboxdr

cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bbox-rw
  namespace: tpsc05busyboxdr
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
  namespace: tpsc05busyboxdr
subjects:
- kind: ServiceAccount
  name: bbox2-user
  namespace: tpsc05busyboxbr
roleRef:
  kind: Role
  name: bbox-rw
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-protection-binding
  namespace: tpsc05busyboxdr
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: trident-protect-tenant-cluster-role
subjects:
- kind: ServiceAccount
  name: bbox2-user
  namespace: tpsc05busyboxbr
EOF

# kubectl auth can-i --as=system:serviceaccount:tpsc05busyboxbr:bbox-user get pods -n tpsc05busyboxdr
# kubectl auth can-i --as=system:serviceaccount:tpsc05busyboxbr:bbox-user get appmirrorrelationship -n tpsc05busyboxdr