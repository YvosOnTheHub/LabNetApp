#########################################################################################
# SCENARIO 8: Create your first App with Block storage
#########################################################################################

GOAL:  
We will deploy the same App as in the scenario 5, but instead of using File Storage, we will use Block Storage

![Scenario8](Images/scenario8.jpg "Scenario8")

## A. Create the app

We will create this app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-SAN backend & storage class have already been created. ([cf Scenario07](../Scenario07))

```
# kubectl create namespace ghostsan
namespace/ghostsan created

# kubectl create -n ghostsan -f Ghost/
persistentvolumeclaim/blog-content created
deployment.apps/blog created
service/blog created

# kubectl get all -n ghostsan
NAME                            READY   STATUS    RESTARTS   AGE
pod/blog-san-58979448dd-6k9ds   1/1     Running   0          21s

NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/blog-san   NodePort   10.99.208.171   <none>        80:30081/TCP   17s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blog-san   1/1     1            1           21s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/blog-san-58979448dd   1         1         1       21s

# kubectl get pvc,pv -n ghostsan
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/blog-content-san   Bound    pvc-8ff8c1b3-48da-400e-893c-23bc9ec459ff   10Gi       RWO            storage-class-san   4m16s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS        REASON   AGE
persistentvolume/pvc-8ff8c1b3-48da-400e-893c-23bc9ec459ff   10Gi       RWO            Delete           Bound    ghostsan/blog-content-san   storage-class-san            4m15s
```

## B. Access the app

It takes about 40 seconds for the POD to be in a *running* state
The Ghost service is configured with a NodePort type, which means you can access it from every node of the cluster on port 30081.
Give it a try !
=> http://192.168.0.63:30081


## C. Explore the app container

Let's see if the */var/lib/ghost/content* folder is indeed mounted to the SAN PVC that was created.

```
# kubectl exec -n ghostsan blog-san-58979448dd-6k9ds -- df /var/lib/ghost/content
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/sdc              10190100     37368   9612060   0% /var/lib/ghost/content

# kubectl exec -n ghostsan blog-san-58979448dd-6k9ds -- ls /var/lib/ghost/content
apps
data
images
logs
lost+found
settings
themes
```


## D. Cleanup

Instead of deleting each object one by one, you can directly delete the namespace which will then remove all of its objects.

```
# kubectl delete ns ghostsan
namespace "ghostsan" deleted
```
