#########################################################################################
# SCENARIO 6: Create your first App with an NVMe namespace
#########################################################################################

**GOAL:**  
We will deploy the same App as in the first chapter of this scenario, but instead of using Block Storage backed by iSCSI, we will use the NVMe over TCP protocol.

<p align="center"><img src="Images/scenario6.jpg"></p>

## A. Create the app

We will create this app in its own namespace (also very useful to clean up everything).  
We consider that the ONTAP-SAN backend for NVMe & storage class have already been created. ([cf Scenario05](../Scenario05))

```bash
$ kubectl create -f Ghost/
namespace/ghost-nvme created
persistentvolumeclaim/blog-content-nvme created
deployment.apps/blog-nvme created
service/blog-nvme created

$ kubectl get -n ghost-nvme all,pvc
NAME                             READY   STATUS    RESTARTS   AGE
pod/blog-nvme-59646cffd7-nxnb6   1/1     Running   0          50m

NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/blog-nvme   NodePort   10.104.73.166   <none>        80:30183/TCP   50m

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blog-nvme   1/1     1            1           50m

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/blog-nvme-59646cffd7   1         1         1       50m

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS         VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/blog-content-nvme   Bound    pvc-571eb30e-0e93-4c61-acf7-ac96d85d6773   5Gi        RWO            storage-class-nvme   <unset>                 50m
```

## B. Access the app

It takes a few seconds for the POD to be in a *running* state
The Ghost service is configured with a NodePort type, which means you can access it from every node of the cluster on port 30183.
Give it a try !
=> `http://192.168.0.63:30183`

## C. Explore the app container

Let's see if the */var/lib/ghost/content* folder is indeed mounted to the SAN PVC that was created.

```bash
$ kubectl exec -n ghost-nvme $(kubectl -n ghost-nvme get pod -o name) -- df /var/lib/ghost/content
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/nvme0n1           5074592       496   4795564   0% /var/lib/ghost/content

$ kubectl exec -n ghost-nvme $(kubectl -n ghost-nvme get pod -o name) -- ls /var/lib/ghost/content
apps
data
images
logs
lost+found
settings
themes
```  

Let's take a look at what we can see at the host level. For that we also need to find out which worker node hosts our pod:  
```bash
$ kubectl get -n ghost-nvme po -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
blog-nvme-59646cffd7-nxnb6   1/1     Running   0          52m   192.168.28.124   rhel2   <none>           <none>
```

Now connect to the corresponding host (_rhel2_ in my case) to validate the configuration:  
```bash
$ lsblk /dev/nvme0n1
NAME    MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
nvme0n1 259:1    0   5G  0 disk /var/lib/kubelet/pods/aa55a855-69ee-40fc-a245-bbefdd8a28da/volumes/kubernetes.io~csi/pvc-571eb30e-0e93-4c61-acf7-ac96d85d6773/mount
```
There you go, you can see that the NVMe namespace is mounted on host to the PVC of our app.

You can also see the connection details on the host with the _nvme list-subsys_ command:
```bash
$ nvme list-subsys
nvme-subsys0 - NQN=nqn.1992-08.com.netapp:sn.7c8b4c9af76e11ee8aac005056b0f629:subsystem.rhel2-189e4ded-d389-4ce6-8395-1d4de202321f
\
 +- nvme0 tcp traddr=192.168.0.139,trsvcid=4420,src_addr=192.168.0.62 live
```

We can see the IP addresses used for the connection, and the connection status.

The nice thing about NVMe is that it can supply metadata about the storage backend. For example we can query the
SVM name and namespace path from the host:
```bash
$ nvme netapp ontapdevices
/dev/nvme0n1, Vserver sansvm, Namespace Path /vol/trident_pvc_3b8fe681_3a2d_4578_b1a3_e464215b8bad/namespace0, NSID 1, UUID 85fc0e10-12de-4051-88c2-7c5aa05f8d1d, 5.37GB
```

You can also try the _nvme list_  command for additional details like the block alignment and namespace serial number.

## E. Cleanup

Instead of deleting each object one by one, you can directly delete the namespace which will then remove all of its objects.

```bash
$ kubectl delete ns ghost-nvme
namespace "ghost-nvme" deleted
```

## F. What's next

Go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)