#########################################################################################
# SCENARIO 4: Create your first App
#########################################################################################

**GOAL:**  
Now that the admin has configured Trident, and has created storage classes, the end-user can request PVC.  

Ghost is a light weight web portal. You will a few YAML files in the Ghost directory:

- a PVC to manage the persistent storage of this app
- a DEPLOYMENT that will define how to manage the app
- a SERVICE to expose the app

<p align="center"><img src="Images/scenario4.jpg"></p>

If you have not yet read the [Addenda09](../../Addendum/Addenda09) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario04_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario04_pull_images.sh my_login my_password
```

## A. Create the app

We will create this app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-NAS backend & storage class have already been created. ([cf Scenario04](../Scenario04))

```bash
$ kubectl create namespace ghost
namespace/ghost created

$ kubectl create -n ghost -f Ghost/
persistentvolumeclaim/blog-content created
deployment.apps/blog created
service/blog created

$ kubectl get all -n ghost
NAME                       READY   STATUS              RESTARTS   AGE
pod/blog-57d7d4886-5bsml   1/1     Running             0          50s

NAME           TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/blog   NodePort   10.97.56.215   <none>        80:30080/TCP   50s

NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blog   1/1     1            1           50s

NAME                             DESIRED   CURRENT   READY   AGE
replicaset.apps/blog-57d7d4886   1         1         1       50s

$ kubectl get pvc,pv -n ghost
NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/blog-content   Bound    pvc-ce8d812b-d976-43f9-8320-48a49792c972   5Gi        RWX            storage-class-nas   4m3s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS        REASON   AGE
persistentvolume/pvc-ce8d812b-d976-43f9-8320-48a49792c972   5Gi        RWX            Delete           Bound    ghost/blog-content          storage-class-nas            4m2s
...
```

## B. Access the app

It takes about 40 seconds for the POD to be in a *running* state
The Ghost service is configured with a NodePort type, which means you can access it from every node of the cluster on port 30080.
Give it a try !
=> http://192.168.0.63:30080

## C. Explore the app container

Let's see if the */var/lib/ghost/content* folder is indeed mounted to the NFS PVC that was created.  
**You need to customize the following commands with the POD name you have in your environment.**

```bash
$ kubectl exec -n ghost blog-57d7d4886-5bsml -- df /var/lib/ghost/content
Filesystem           1K-blocks      Used Available Use% Mounted on
192.168.0.135:/ansible_pvc_ce8d812b_d976_43f9_8320_48a49792c972
                       5242880       704   5242176   0% /var/lib/ghost/content


$ kubectl exec -n ghost blog-57d7d4886-5bsml -- ls /var/lib/ghost/content
apps
data
images
logs
lost+found
settings
themes
```

If you have configured Grafana, you can go back to your dashboard, to check what is happening (cf http://192.168.0.63:30267).  

## D. Cleanup (optional)

:boom:  
**The PVC will be reused in the [scenario8](../Scenario08) ('import a volume'). Only clean up if you dont plan to do the scenario8.**  
Instead of deleting each object one by one, you can directly delete the namespace which will then remove all of its objects.  
:boom:  

```bash
$ kubectl delete ns ghost
namespace "ghost" deleted
```

## E. What's next

I hope you are getting more familiar with Trident now. You can move on to:

- [Scenario05](../Scenario05): Configure your first iSCSI backends & storage classes 
- [Scenario07](../Scenario07): Use the 'import' feature of Trident  
- [Scenario08](../Scenario08): Consumption control  
- [Scenario09](../Scenario09): Resize a NFS CSI PVC  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)