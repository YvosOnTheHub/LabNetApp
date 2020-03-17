#####################################################
# SCENARIO 5: Create your App
#####################################################

GOAL:
Now that the admin has configured Trident, and has created storage classes, the end-user can request PVC.

Ghost is a light weight web portal. You will a few YAML files in the Ghost directory:
- a PVC to manage the persistent storage of this app
- a DEPLOYMENT that will define how to manage the app
- a SERVICE to expose the app

## A. Create the app

We will create this app in its own namespace (also very useful to clean up everything)

```
kubectl create namespace ghost
namespace/ghost created

kubectl create -n ghost -f Ghost/
persistentvolumeclaim/blog-content created
deployment.apps/blog created
service/blog created

kubectl get all -n ghost
NAME                       READY   STATUS    RESTARTS   AGE
pod/blog-57d7d4886-9ghhx   1/1     Running   0          34s

NAME           TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/blog   NodePort   10.108.251.208   <none>        80:30080/TCP   34s

NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blog   1/1     1            1           34s

NAME                             DESIRED   CURRENT   READY   AGE
replicaset.apps/blog-57d7d4886   1         1         1       34s


kubectl get pvc,pv -n ghost
NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/blog-content   Bound    pvc-be16c3e7-808e-4818-b1bd-2fd386e29188   5Gi        RWX            storage-class-nas   26m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                STORAGECLASS        REASON   AGE
persistentvolume/pvc-be16c3e7-808e-4818-b1bd-2fd386e29188   5Gi        RWX            Delete           Bound    ghost/blog-content   storage-class-nas            26m
```

## B. Access the app

The Ghost service is configured with a NodePort type, which means you can access it from every node of the cluster on port 30080.
Give it a try !
=> http://192.168.0.63:30080


## C. Cleanup

Instead of deleteing each object one by one, you can directly delete the namespace which will then remove all of its objects.

```
kubectl delete ns ghost
namespace "ghost" deleted
```
