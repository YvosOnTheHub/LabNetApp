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

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario24_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario05_pull_images.sh
```

Let's start by deploying our app and wait a few second for it to be ready:  
```bash
$ kubectl create -f busybox.yaml
namespace/tpsc05busybox created
persistentvolumeclaim/mydata1 created
persistentvolumeclaim/mydata2 created
deployment.apps/busybox created

$ kubectl get -n tpsc05busybox pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-cr6fd   1/1     Running   0          15s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-93859da5-107d-4b08-9ca3-e8533c226852   1Gi        RWX            storage-class-nfs   <unset>                 15s
persistentvolumeclaim/mydata2   Bound    pvc-b09001f8-8b57-4863-b275-961de4edb2ad   1Gi        RWX            storage-class-nfs   <unset>                 15s

$ kubectl -n tpsc05busybox exec $(kubectl get -n tpsc05busybox po -o name) -- df /data1 /data2
Filesystem           1K-blocks      Used Available Use% Mounted on
192.168.0.131:/trident_pvc_93859da5_107d_4b08_9ca3_e8533c226852
                       1048576       256   1048320   0% /data1
192.168.0.131:/trident_pvc_b09001f8_8b57_4863_b275_961de4edb2ad
                       1048576       256   1048320   0% /data2
```

In order to test all the scenarios, let's write some data in those 2 volumes and check the result:  
```bash
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- sh -c 'echo "bbox test1 in folder data1!" > /data1/file.txt'
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- more /data1/file.txt
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- sh -c 'echo "bbox test1 in folder data2!" > /data2/file.txt'
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- more /data2/file.txt
```

Default users do not have the right create a Trident Protect *application*.  
You can verify this by running the following command:  
```bash
$ kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:default get applications.protect.trident.netapp.io -n tpsc05busybox
no
```

For an application owner to start protecting his environment, the admin first needs to give him some credentials.  
Let's create a specific *Service Account* which has the permission to create & manage Trident Protect applications (_ClusterRole: trident-protect-tenant-cluster-role_):  
```bash
$ kubectl create sa -n tpsc05busybox protect-user
serviceaccount/protect-user created

$ cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  annotations:
    kubernetes.io/service-account.name: protect-user
  name: protect-user-secret
  namespace: tpsc05busybox
type: kubernetes.io/service-account-token
EOF

$ cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bbox-tenant-rolebinding
  namespace: tpsc05busybox
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: trident-protect-tenant-cluster-role
subjects:
- kind: ServiceAccount
  name: protect-user
  namespace: tpsc05busybox
EOF
```
Let's now verify that this service account has the necesary rights to proceed:  
```bash
$ kubectl auth can-i --as=system:serviceaccount:tpsc05busybox:protect-user get applications.protect.trident.netapp.io -n tpsc05busybox
yes
```

Now that the setup is complete, you can continue to the next chapter: [Protect your application](./1_App_Protect/).
