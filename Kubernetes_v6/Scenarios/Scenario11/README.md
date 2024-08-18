#########################################################################################
# SCENARIO 11: StatefulSets & Storage consumption
#########################################################################################

**GOAL:**  
StatefulSets work differently that Deployments or DaemonSets when it comes to storage.  
Deployments & DaemonSets use PVC defined outside of them, whereas StatefulSets include the storage in their definition (cf _volumeClaimTemplates_).  
Said differently, you can see a StatefulSet as a couple (POD + Storage). When it is scaled, both objects will be automatically created.  
In this exercise, we will create a MySQL StatefulSet & Scale it.  

We consider that a backend & a storage class have already been created. ([ex: Scenario02](../Scenario02)).  

<p align="center"><img src="Images/scenario11.jpg"></p>

To best benefit from the scenario, you would first need to go through the following Addendum:  
[1.](../../Addendum/Addenda01) Add a node to the cluster  
[2.](../../Addendum/Addenda02) Specify a default storage class if different from the existing one  
[3.](../../Addendum/Addenda03) Allow user PODs on the master node  

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario11_pull_images.sh_ to pull images utilized in this scenario. These images will then be pushed to the LoD private repo.  
It uses 2 **optional** parameters, your Docker Hub _login_ & _password_:  
```bash
sh scenario11_pull_images.sh my_login my_password
```

## A. Let's start by creating the application

This application is based on 3 elements:  
- a ConfigMap, which hosts some parameter for the application
- 2 services
- the StatefulSet (3 replicas of the application)

:mag:  
*A* **ConfigMap** *is an API object used to store non-confidential data in key-value pairs. Pods can consume ConfigMaps as environment variables, command-line arguments, or as configuration files in a volume. A ConfigMap allows you to decouple environment-specific configuration from your container images, so that your applications are easily portable.*  
:mag_right:  

```bash
$ kubectl create -f mysql.yaml
namespace/mysql created
configmap/mysql created
service/mysql created
service/mysql-read created
statefulset.apps/mysql created
```

If you don't configure any rule, you may end up with all 3 replicas running on one node.  
If you would like to even out or balance pods accross the whole cluster, to mimic daemonsets for instance, you would need to set a _podantiaffinity_ rule. There is one already present in the _mysql.yaml_ manifest. Check it out!  

It will take a few minutes for all the replicas to be created, I will then suggest using the _watch_ flag:  
```bash
$ kubectl -n mysql get pod --watch
mysql-0   1/2     Running   0          43s   10.36.0.1   rhel1   <none>           <none>
mysql-0   2/2     Running   0          52s   10.36.0.1   rhel1   <none>           <none>
mysql-1   0/2     Pending   0          0s    <none>      <none>   <none>           <none>
mysql-1   0/2     Pending   0          0s    <none>      <none>   <none>           <none>
mysql-1   0/2     Pending   0          4s    <none>      rhel2    <none>           <none>
mysql-1   0/2     Init:0/2   0          4s    <none>      rhel2    <none>           <none>
mysql-1   0/2     Init:1/2   0          24s   10.44.0.1   rhel2    <none>           <none>
mysql-1   0/2     Init:1/2   0          32s   10.44.0.1   rhel2    <none>           <none>
mysql-1   0/2     PodInitializing   0          40s   10.44.0.1   rhel2    <none>           <none>
...
```

Once you that the third POD is up & running, you are good to go  
```bash
$ kubectl -n mysql get pod -o wide
NAME      READY   STATUS    RESTARTS   AGE   IP          NODE    NOMINATED NODE   READINESS GATES
mysql-0   2/2     Running   0          24h   10.36.0.1   rhel1   <none>           <none>
mysql-1   2/2     Running   1          24h   10.44.0.1   rhel2   <none>           <none>
mysql-2   2/2     Running   1          24h   10.39.0.2   rhel4   <none>           <none>
```

Now, check the storage. You can see that 3 PVC were created, one per POD.  
```bash
$ kubectl get -n mysql pvc
NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/data-mysql-0   Bound    pvc-f348ec0a-f304-49d8-bbaf-5a85685a6194   10Gi       RWO            storage-class-nfs   5m
persistentvolumeclaim/data-mysql-1   Bound    pvc-ce114401-5789-454a-ba1c-eb5453fbe026   10Gi       RWO            storage-class-nfs   5m
persistentvolumeclaim/data-mysql-2   Bound    pvc-99f98294-85f6-4a69-8f50-eb454ed00868   10Gi       RWO            storage-class-nfs   4m
```

## B. Let's write some data in this database !

To connect to MySQL, we will use another POD which will connect to the master DB (mysql-0).  
As there are windows nodes in the cluster, we need to make sure our pod runs on a linux based worker node, hence the _override_ parameter.  
Copy & paste the whole block at once:  
```bash
$ kubectl run mysql-client -n mysql --image=registry.demo.netapp.com/mysql:5.7.30 -i --rm --restart=Never --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{ "kubernetes.io/os":"linux"}}}' -- mysql -h mysql-0.mysql <<EOF
CREATE DATABASE test;
CREATE TABLE test.messages (message VARCHAR(250));
INSERT INTO test.messages VALUES ('hello');
EOF
```

Let's check that the operation was successful by reading the database, through the service called _mysql-read_  
```bash
$ kubectl run mysql-client -n mysql --image=registry.demo.netapp.com/mysql:5.7.30 -i -t --rm --restart=Never --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{ "kubernetes.io/os":"linux"}}}' -- mysql -h mysql-read -e "SELECT * FROM test.messages"
If you don't see a command prompt, try pressing enter.
+---------+
| message |
+---------+
| hello   |
+---------+
pod "mysql-client" deleted
```

## C. Where are my reads coming from ?

In the current setup, _writes_ are done on the master DB, wheareas _reads_ can come from any DB POD.  
Let's check this!  
First, open a new Putty window & connect to RHEL3. You can then run the following, which will display the ID of the database followed by a timestamp.  
```bash
$ kubectl run mysql-client-loop -n mysql --image=registry.demo.netapp.com/mysql:5.7.30 -i -t --rm --restart=Never --overrides='{"apiVersion":"v1","spec":{"nodeSelector":{ "kubernetes.io/os":"linux"}}}' -- bash -ic "while sleep 1; do mysql -h mysql-read -e 'SELECT @@server_id,NOW()'; done"
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         100 | 2024-07-27 10:22:32 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         102 | 2024-24-27 10:22:33 |
+-------------+---------------------+
```

As you can see, _reads_ are well distributed between all the PODs.  
Keep this window open for now...

## D. Let's scale !

Scaling an application with Kubernetes is pretty straightforward & can be achieved with the following command:  
```bash
$ kubectl scale statefulset mysql -n mysql --replicas=4
statefulset.apps/mysql scaled
```

You can use the _kubectl get pod_ with the _--watch_ parameter again to see the new POD starting.  
When done, you should have someething similar to this:  
```bash
$ kubectl get pod -n mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   2/2     Running   0          12m
mysql-1   2/2     Running   0          12m
mysql-2   2/2     Running   0          11m
mysql-3   2/2     Running   1          3m13s
```

Notice the last POD is _younger_ that the other ones...  
Again, check the storage. You can see that a new PVC was automatically created.  
```bash
$ kubectl get -n mysql pvc
NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/data-mysql-0   Bound    pvc-f348ec0a-f304-49d8-bbaf-5a85685a6194   10Gi       RWO            storage-class-nfs   15m
persistentvolumeclaim/data-mysql-1   Bound    pvc-ce114401-5789-454a-ba1c-eb5453fbe026   10Gi       RWO            storage-class-nfs   15m
persistentvolumeclaim/data-mysql-2   Bound    pvc-99f98294-85f6-4a69-8f50-eb454ed00868   10Gi       RWO            storage-class-nfs   14m
persistentvolumeclaim/data-mysql-3   Bound    pvc-8758aaaa-33ab-4b6c-ba42-874ce6028a49   10Gi       RWO            storage-class-nfs   6m18s
```

Also, if the second window is still open, you should start seeing new _id_ ('103' anyone?):  
```bash
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         102 | 2024-07-27 10:25:51 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         103 | 2024-07-27 10:25:53 |
+-------------+---------------------+
+-------------+---------------------+
| @@server_id | NOW()               |
+-------------+---------------------+
|         101 | 2024-07-27 10:25:54 |
+-------------+---------------------+
```

## E. Clean up

```bash
$ kubectl delete namespace mysql
namespace "mysql" deleted
```

## F. What's next

You can now move on to:

- [Scenario13](../Scenario13): Dynamic export policy management  
- [Scenario14](../Scenario14): On-Demand Snapshots & Create PVC from Snapshot  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
