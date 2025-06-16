export KUBECONFIG=/root/.kube/config
kubectl config use-context kub2-admin@kub2

kubectl create ns tpsc05busyboxbr

kubectl create serviceaccount bbox2-user -n tpsc05busyboxbr

cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bbox-rw
  namespace: tpsc05busyboxbr
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
  namespace: tpsc05busyboxbr
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
  namespace: tpsc05busyboxbr
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: trident-protect-tenant-cluster-role
subjects:
- kind: ServiceAccount
  name: bbox2-user
  namespace: tpsc05busyboxbr
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bbox-user-appvault
  namespace: trident-protect
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["s3-creds"]
  verbs: ["get"]
- apiGroups: ["protect.trident.netapp.io"]
  resources: ["appvaults"]
  resourceNames: ["ontap-vault"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-user-appvault-binding
  namespace: trident-protect
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: bbox-user-appvault
subjects:
- kind: ServiceAccount
  name: bbox2-user
  namespace: tpsc05busyboxbr
EOF

# kubectl auth can-i --as=system:serviceaccount:tpsc05busyboxbr:bbox2-user get pods -n tpsc05busyboxbr
# kubectl auth can-i --as=system:serviceaccount:tpsc05busyboxbr:bbox2-user get snapshotrestores -n tpsc05busyboxbr

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  annotations:
    kubernetes.io/service-account.name: bbox2-user
  name: bbox-user-secret
  namespace: tpsc05busyboxbr
type: kubernetes.io/service-account-token
EOF

TOKEN=$(kubectl get secret bbox-user-secret -n tpsc05busyboxbr -o jsonpath="{.data.token}" | base64 --decode)
CA_CRT=$(kubectl get secret bbox-user-secret -n tpsc05busyboxbr -o jsonpath="{.data['ca\.crt']}" | base64 --decode)
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KUBECONFIG_FILE=/root/.kube/tpsc05-rhel5

kubectl config set-cluster $CLUSTER_NAME --server=$SERVER --certificate-authority=<(echo "$CA_CRT") --kubeconfig=$KUBECONFIG_FILE --embed-certs=true
kubectl config set-credentials bbox2-user --token=$TOKEN --kubeconfig=$KUBECONFIG_FILE
kubectl config set-context bbox-context-kub2 --cluster=$CLUSTER_NAME --user=bbox2-user --namespace=tpsc05busyboxbr --kubeconfig=$KUBECONFIG_FILE
kubectl config use-context bbox-context-kub2 --kubeconfig=$KUBECONFIG_FILE

scp -p /root/.kube/tpsc05-rhel5 rhel5:/root/.kube/tpsc05-rhel5

export KUBECONFIG=~/.kube/tpsc05-rhel3:~/.kube/tpsc05-rhel5
kubectl config view --merge --flatten > ~/.kube/tpsc05-config
export KUBECONFIG=~/.kube/tpsc05-config

kubectl config use-context bbox-context-kub2