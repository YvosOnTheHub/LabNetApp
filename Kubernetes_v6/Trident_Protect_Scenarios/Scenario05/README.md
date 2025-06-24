#########################################################################################
# SCENARIO 5: Tests scenario with Busybox
#########################################################################################  

Simple tests can be done with a busybox app connected to persistent volumes.  
In this scenario, we will see how to :  
- Create a Trident Protect app  
- Create a manual snapshot & a manual backup  
- Apply a data protection schedule to the app  
- Restore in all its forms (from snapshot, from backup, full or partial, in-place or to a different target)  
- Implement a disaster recovery plan (failover, reverser resync & failback)  

Also, let's consider we have 2 different personas in this scenario:  
- the Kubernetes admin who creates the user namespace, his service account & kubeconfig file, as well as the Trident Protect AppVault  
- the user who can deploy and protect his own application  

That way you can see who has the responbility to perform tasks in each steps.  

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario05_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario05_pull_images.sh
```

## A. Kubernetes admin: namespace setup

When a new request comes in from an app team, the Kubenetes admin will perform the following tasks:  
- create a new namespace   
- create a service account and the associated kubeconfig file  

Let's start with the _namespace_ and the _service account_:  
```bash
$ kubectl create ns tpsc05busybox
namespace/tpsc05busybox created

$ kubectl create serviceaccount bbox-user -n tpsc05busybox
serviceaccount/bbox-user created
```

The team requesting that namespace *must not* have access to other namespaces, however it will get several rights to act on resources in that environment. For this, the admin will create a _role_ and bind it to the _service account_.  
```bash
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bbox-rw
  namespace: tpsc05busybox
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
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-rw-binding
  namespace: tpsc05busybox
subjects:
- kind: ServiceAccount
  name: bbox-user
  namespace: tpsc05busybox
roleRef:
  kind: Role
  name: bbox-rw
  apiGroup: rbac.authorization.k8s.io
EOF
role.rbac.authorization.k8s.io/bbox-rw created
rolebinding.rbac.authorization.k8s.io/bbox-rw-binding created
```
Before creating the kubeconfig file provided to the application owner, the admin also needs to create a _secret_.  
In this example, this secret will contain a _token_ randomly generated.
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  annotations:
    kubernetes.io/service-account.name: bbox-user
  name: bbox-user-secret
  namespace: tpsc05busybox
type: kubernetes.io/service-account-token
EOF
secret/bbox-user-secret created
```
Last, the admin can now generate a new KubeConfig file that will be transfered to the application team.  
You can just copy and paste the following lines to achieve this.
```bash
TOKEN=$(kubectl get secret bbox-user-secret -n tpsc05busybox -o jsonpath="{.data.token}" | base64 --decode)
CA_CRT=$(kubectl get secret bbox-user-secret -n tpsc05busybox -o jsonpath="{.data['ca\.crt']}" | base64 --decode)
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KUBECONFIG_FILE=/root/.kube/tpsc05-rhel3

kubectl config set-cluster $CLUSTER_NAME --server=$SERVER --certificate-authority=<(echo "$CA_CRT") --kubeconfig=$KUBECONFIG_FILE --embed-certs=true
kubectl config set-credentials bbox-user --token=$TOKEN --kubeconfig=$KUBECONFIG_FILE
kubectl config set-context bbox-context-kub1 --cluster=$CLUSTER_NAME --user=bbox-user --namespace=tpsc05busybox --kubeconfig=$KUBECONFIG_FILE
kubectl config use-context bbox-context-kub1 --kubeconfig=$KUBECONFIG_FILE
```

## B. Application owner: app deployment

The application owner just received his kubeconfig file.  
Let's verify if we can list resources:  
```bash
$ kubectl get ns --kubeconfig=/root/.kube/tpsc05-rhel3
Error from server (Forbidden): namespaces is forbidden: User "system:serviceaccount:tpsc05busybox:bbox-user" cannot list resource "namespaces" in API group "" at the cluster scope

$ kubectl get -n trident po --kubeconfig=/root/.kube/tpsc05-rhel3
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:tpsc05busybox:bbox-user" cannot list resource "pods" in API group "" in the namespace "trident"

$ kubectl get --kubeconfig=/root/.kube/tpsc05-rhel3 po,pvc
No resources found in tpsc05busybox namespace.
```
As you can see, you are limited in what you can do.  
In the third command, notice there is no explicit mention of the _tpsc05busybox_ namespace.  
However, since the credentials are limited to that environment, Kubernetes will know where to look for information.  
Also, you have not yet created an app, which explains why there is no POD nor PVC found.  

In order to simplify the commands to run, let's set the KUBECONFIG variable to the new reference file.  
That way, you will not need to use the _--kubeconfig_ parameter when impersonating the application owner:  
```bash
export KUBECONFIG=/root/.kube/tpsc05-rhel3
```
Time to deploy Busybox!    
```bash
$ kubectl create -f busybox.yaml
persistentvolumeclaim/mydata1 created
persistentvolumeclaim/mydata2 created
deployment.apps/busybox created

$ kubectl get pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-44skr   1/1     Running   0          48s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-1de7ac03-98cf-4e28-9ccb-a0c7e814c3bb   1Gi        RWX            storage-class-nfs   <unset>                 48s
persistentvolumeclaim/mydata2   Bound    pvc-83750f7e-0d88-4e98-aaee-9e50a8a76a4a   1Gi        RWX            storage-class-nfs   <unset>                 48s

$ kubectl exec $(kubectl get po -o name) -- df -h /data1 /data2
Filesystem                Size      Used Available Use% Mounted on
192.168.0.131:/trident_pvc_1de7ac03_98cf_4e28_9ccb_a0c7e814c3bb
                          1.0G    320.0K   1023.7M   0% /data1
192.168.0.131:/trident_pvc_83750f7e_0d88_4e98_aaee_9e50a8a76a4a
                          1.0G    320.0K   1023.7M   0% /data2
```

In order to test all the scenarios, let's write some data in those 2 volumes and check the result:  
```bash
kubectl exec $(kubectl get pod -o name) -- sh -c 'echo "bbox test1 in folder data1!" > /data1/file.txt'
kubectl exec $(kubectl get pod -o name) -- more /data1/file.txt
kubectl exec $(kubectl get pod -o name) -- sh -c 'echo "bbox test1 in folder data2!" > /data2/file.txt'
kubectl exec $(kubectl get pod -o name) -- more /data2/file.txt
```
The application is now in production!  
The app owner now would like to protect it with Trident Protect and asks if the Kubernetes admin can update the credentials.

## C. Kubernetes admin: Trident Protect capabilities

To impersonate the Kubernetes admin, let's switch back to the first config file:
```bash
export KUBECONFIG=/root/.kube/config
```

Now, let's see if the app owner is allowed to use Trident Protect, ie can he create an _application_:
```bash
$ kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:bbox-user get applications.protect.trident.netapp.io -n tpsc05busybox
no
```
By default, users do not have the capability to create a Trident Protect *application*.  

When Trident Protect was installed, a bunch of predefined _cluster roles_ were created.  
You can get the list by running the following:  
```bash
$ kubectl get clusterrole -l app.kubernetes.io/name=trident-protect
NAME                                  CREATED AT
trident-protect-autosupportbundle     2025-06-02T06:07:19Z
trident-protect-exechook              2025-06-02T06:07:19Z
trident-protect-manager-role          2025-06-02T06:07:19Z
trident-protect-metrics-reader        2025-06-02T06:07:19Z
trident-protect-proxy-role            2025-06-02T06:07:19Z
trident-protect-resourcebackup        2025-06-02T06:07:19Z
trident-protect-resourcedelete        2025-06-02T06:07:19Z
trident-protect-resourcerestore       2025-06-02T06:07:19Z
trident-protect-tenant-cluster-role   2025-06-02T06:07:19Z
```
The Kubernetes admin would like to provide complete ownership to the App owner for the protection.  
We will then use the _trident-protect-tenant-cluster-role_ role which includes everything required.
```bash
$ cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-protection-binding
  namespace: tpsc05busybox
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: trident-protect-tenant-cluster-role
subjects:
- kind: ServiceAccount
  name: bbox-user
  namespace: tpsc05busybox
EOF
rolebinding.rbac.authorization.k8s.io/bbox-protection-binding created
```
Let's quickly check that the App owner now has the capability to protect his app:
```bash
$ kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:bbox-user get applications.protect.trident.netapp.io -n tpsc05busybox
yes
```
 
If you have not yet created an AppVault, refer to the [Scenario03](../../Scenario03/) which guides you through the bucket provisioning as well as the AppVault (_ontap-vault_), that is created in the Trident Protect namespace, by the admin.  
This AppVault should be present on both Kubernetes clusters.  

The admin needs to allow access to this AppVault so that the App Owner can start his protection policies.

Let's verify that the application service account does not have permission to use the AppVault:  
```bash
$ kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:bbox-user get appvaults.protect.trident.netapp.io/ontap-vault -n trident-protect
no
```

To allow access, let's create a specific role and bind it to our service account:
```bash
$ cat << EOF | kubectl apply -f -
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
  name: bbox-user
  namespace: tpsc05busybox
EOF
role.rbac.authorization.k8s.io/bbox-user-appvault created
rolebinding.rbac.authorization.k8s.io/bbox-user-appvault-binding created
```
Let's check the result:
```bash
$ kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:bbox-user get appvaults.protect.trident.netapp.io/ontap-vault -n trident-protect
yes
```

Now that the setup is complete, you can continue to the next chapter: [Protect your application](./1_App_Protect/).