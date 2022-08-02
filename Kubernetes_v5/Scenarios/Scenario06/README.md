#########################################################################################
# SCENARIO 6: Create your first App with Block storage
#########################################################################################

**GOAL:**  
We will deploy the same App as in the scenario 4, but instead of using File Storage, we will use Block Storage.

<p align="center"><img src="Images/scenario6.jpg"></p>

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario06_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario06_pull_images.sh my_login my_password
```

## A. Create the app

We will create this app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-SAN backend & storage class have already been created. ([cf Scenario05](../Scenario05))

```bash
$ kubectl create namespace ghostsan
namespace/ghostsan created

$ kubectl create -n ghostsan -f Ghost/
persistentvolumeclaim/blog-content created
deployment.apps/blog created
service/blog created

$ kubectl get -n ghostsan all,pvc,pv
NAME                            READY   STATUS    RESTARTS   AGE
pod/blog-san-57f487f777-l6g9t   1/1     Running   0          51s

NAME               TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/blog-san   NodePort   10.103.121.182   <none>        80:30180/TCP   51s

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blog-san   1/1     1            1           51s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/blog-san-57f487f777   1         1         1       51s

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/blog-content-san   Bound    pvc-f243591e-757a-47bb-9d9c-ca24f8d3158a   5Gi        RWO            storage-class-san   51s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS        REASON   AGE
persistentvolume/pvc-f243591e-757a-47bb-9d9c-ca24f8d3158a   5Gi        RWO            Delete           Bound    ghostsan/blog-content-san   storage-class-san            50s
```

## B. Access the app

It takes about 40 seconds for the POD to be in a *running* state
The Ghost service is configured with a NodePort type, which means you can access it from every node of the cluster on port 30180.
Give it a try !
=> `http://192.168.0.63:30180`

## C. Explore the app container

Let's see if the */var/lib/ghost/content* folder is indeed mounted to the SAN PVC that was created.

```bash
$ kubectl exec -n ghostsan $(kubectl -n ghostsan get pod -o name) -- df /var/lib/ghost/content
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/sdc               5029504     20944   4730032   0% /var/lib/ghost/content

$ kubectl exec -n ghostsan $(kubectl -n ghostsan get pod -o name) -- ls /var/lib/ghost/content
apps
data
images
logs
lost+found
settings
themes
```

If you have configured Grafana, you can go back to your dashboard, to check what is happening (cf http://192.168.0.63:30267).  

## D. Validate the CHAP configuration on the host

This application was deployed using secured authentication with the storage backend. We can now see the configuration on the host.  
Let's first look at what server hosts the POD:

```bash
$ kubectl get -n ghostsan pod -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP          NODE    NOMINATED NODE   READINESS GATES
blog-san-58979448dd-6k9ds   1/1     Running   0          35m   10.44.0.1   rhel2   <none>           <none>
```

Now that host had been identified, let's take a look at CHAP (on _host2_ in this case)

```bash
iscsiadm -m session -P 3 | grep CHAP -A 5
                CHAP:
                *****
                username: uh2a1io325bFFILn
                password: ********
                username_in: iJF4sgjrnwOwQ
                password_in: ********
```

There you go, you have just validated the CHAP configuration!

## E. Cleanup

Instead of deleting each object one by one, you can directly delete the namespace which will then remove all of its objects.

```bash
$ kubectl delete ns ghostsan
namespace "ghostsan" deleted
```

## F. What's next

Now that you have tried working with SAN backends, you can try to resize a PVC:

- [Scenario09](../Scenario09): Resize a iSCSI CSI PVC  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)