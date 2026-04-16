#########################################################################################
# SCENARIO 8: Protection policies & GitOps
#########################################################################################  

In this scenario, we are going see how we can automatically protect an application with Trident Protect & ArgoCD:
<p align="center"><img src="Images/Scenario_architecture.png" width="728"></p>

## A. Wordpress deployment with ArgoCD

Let's deploy a new application. Instead of creating it with Helm, we are going to use ArgoCD.  
This could be done with the GUI or via the ArgoCD CRD, method used in the following example:  
```bash
$ kubectl create -f ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario08/1_Snapshot/argocd_wordpress_deploy.yaml
application.argoproj.io/wordpress created
```
In a nutshell, we defined in the _argocd_wordpress_deploy.yaml_ file the following:
- the repo where the YAML manifests are stored ("ht<span>tp://</span>192.168.0.203:30000/demo/wordpress")
- the directory to use in that repo (Wordpress_Snapshot/App_config)
- the target namespace (wpargo1)  

If all went well, you would see the app in the ArgoCD GUI:
<p align="center"><img src="Images/ArgoCD_wordpress_create_missing.png" width="384"></p>

For the purpose of this exercice, this card does not automatically sync its content. A production grade configuration would look differently.  
In order for ArgoCD to deploy Wordpress, you can press on the **Sync** button on the app tile (leave all options as is).  
The application will immediately appear on the Kubernetes cluster:   
```bash
$ kubectl get -n wpargo1 pod,svc,pvc
NAME                                   READY   STATUS    RESTARTS   AGE
pod/wordpress-7c945b79c8-zv7sl         1/1     Running   0          3m52s
pod/wordpress-mysql-7c4d5fc78c-4xpjh   1/1     Running   0          3m52s

NAME                      TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
service/wordpress         LoadBalancer   172.28.187.240   192.168.0.213   80:32467/TCP   3m52s
service/wordpress-mysql   ClusterIP      None             <none>          3306/TCP       3m52s

NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS         AGE
persistentvolumeclaim/mysql-pvc   Bound    pvc-9dc10e4f-54a8-45fe-a7db-4765b53b6165   20Gi       RWO            storage-class-nfs    3m52s
persistentvolumeclaim/wp-pvc      Bound    pvc-86ec7250-3566-48db-be92-107dd7e5eb88   20Gi       RWO            storage-class-nfs    3m52s
```
In the ArgoCD, once the application is fully deployed, you can the following:  
<p align="center"><img src="Images/ArgoCD_wordpress_deployed.png" width="384"></p>


Connect to the address assigned by the Load Balancer (_192.168.0.213_ in this example) to check that it works.  
I recommend adding your own blog, so that you can really understand Trident Protect's benefits.  

## B. Wordpress protection with ArgoCD

Time to protect this application!  
The repo also has a few files in the _App_protect_ folder to create some Trident Protect CR:
- _wordpress-application.yaml_ to define the frontend as a Trident Protect application
- _mysql-application.yaml_ to define the backend as a Trident Protect application  
- _wordpress-schedule.yaml_ to automatically take snapshots of the frontend  
- _mysql-schedule.yaml_ to automatically take snapshots of the backend  
- _mysql-hook-pre-snap.yaml_ to quiesce the database so that the snapshot is consistent  
- _mysql-hook-post-snap.yaml_ to thaw the database  

>> Note that the pre snapshot hook used in this scenario will freeze the database for some time.    
>> The effect is that if you try to update the blog while the snapshot process is running, saving the result will wait for the database to be thawed.  
>> If you do not setup the hooks, the snapshot is almost immediate, which is fine for a demo, but maybe not for production...  

We defined in the _argocd_wordpress_protect.yaml_ file the following:
- the repo where the YAML manifests are stored ("ht<span>tp://</span>192.168.0.203:30000/demo/wordpress")  
- the directory to use in that repo (Wordpress_Snapshot/App_protect)  

The protecting schedule is configured this way:  
- frontend: hourly (10 minutes after the top of the hour) 
- backend: every 15 minutes  

You may want to change the frontend schedule if you want to witness quickly the creation of scheduled snapshots.  
The schedule also contain the parameter "runImmediately: true", which triggers the creation of snapshot as soon as the configuration is deployed.  
```bash
$ kubectl create -f ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario08/1_Snapshot/argocd_wordpress_protect.yaml
application.argoproj.io/trident-protect-wordpress-app created
```
If all went well, you would see the app in the ArgoCD GUI:
<p align="center"><img src="Images/ArgoCD_wordpress_protected.png" width="384"></p>

Checked in the CLI, you can also see that the Trident Protect configuration is present, which means your application has been automatically set up for protection!  
```bash
$ tridentctl-protect get application -n wpargo1
+--------------------+------------+-------+-------+
|        NAME        | NAMESPACES | STATE |  AGE  |
+--------------------+------------+-------+-------+
| wordpress-frontend | wpargo1    | Ready | 3m14s |
| wordpress-mysql    | wpargo1    | Ready | 3m14s |
+--------------------+------------+-------+-------+

$ tridentctl-protect get schedule -n wpargo1
+--------------------+--------------------+---------------------------------+---------+-------+-----+-------+
|        NAME        |        APP         |            SCHEDULE             | ENABLED | STATE | AGE | ERROR |
+--------------------+--------------------+---------------------------------+---------+-------+-----+-------+
| wordpress-frontend | wordpress-frontend | Hourly:min=10                   | true    |       | 15s |       |
| wordpress-mysql    | wordpress-mysql    | DTSTART:20250106T000100Z        | true    |       | 15s |       |
|                    |                    | RRULE:FREQ=MINUTELY;INTERVAL=15 |         |       |     |       |
+--------------------+--------------------+---------------------------------+---------+-------+-----+-------+

$ tridentctl-protect get exechook -n wpargo1
+-----------------+-----------------+---------------------+----------+-------+---------+-----+-------+
|      NAME       |       APP       |        MATCH        |  ACTION  | STAGE | ENABLED | AGE | ERROR |
+-----------------+-----------------+---------------------+----------+-------+---------+-----+-------+
| mysql-snap-post | wordpress-mysql | containerName:mysql | Snapshot | Post  | true    | 44s |       |
| mysql-snap-pre  | wordpress-mysql | containerName:mysql | Snapshot | Pre   | true    | 42s |       |
+-----------------+-----------------+---------------------+----------+-------+---------+-----+-------+
```
Depending on the schedule set, you should see soon or later snapshots appear.  
Notice the difference of timing
```bash
$ tridentctl-protect get snapshot -n wpargo1
+-----------------------------+--------------------+----------------+-----------+-------+--------+
|            NAME             |        APP         | RECLAIM POLICY |   STATE   | ERROR |   AGE  |
+-----------------------------+--------------------+----------------+-----------+-------+--------+
| custom-cc413-20250126160600 | wordpress-mysql    | Delete         | Completed |       | 30m37s |
| custom-cc413-20250126162100 | wordpress-mysql    | Delete         | Completed |       | 15m37s |
| custom-cc413-20250126163600 | wordpress-mysql    | Delete         | Completed |       | 37s    |
| hourly-03413-20250126161000 | wordpress-frontend | Delete         | Completed |       | 1m24s  |
+-----------------------------+--------------------+----------------+-----------+-------+--------+
```

## C. Snapshot Restore

Now what?  
SEEK & DESTROY !!  

In order to break stuff, you need write access to the database. If a snasphot is running, the pre-Hook runs the SQL command _FLUSH TABLES WITH READ LOCK_, which removes momentarily write access.  
Check that there is no snapshot running at this point (and if it is the case, wait for it to finish).  
```bash
kubectl get -n wpargo1 snapshot | grep wordpress-mysql  | grep -v Completed
```
Or if you want to move forward quickly, you can just kill all the hook's Sleep processes to release the lock:  
```bash
kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- \
  sh -c 'export MYSQL_PWD=Netapp1!; \
  mysql -Nse "SELECT id FROM information_schema.processlist WHERE info LIKE '\''SELECT SLEEP%'\'';" \
  | while read id; do mysql -e "KILL $id"; done'
```

Let's delete the **wordpress** database, just for fun ...  
```bash
$ kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- sh -c 'export MYSQL_PWD=Netapp1!; mysql -e "SHOW DATABASES;"'
Database
information_schema
mysql
performance_schema
sys
wordpress

$ kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- sh -c 'export MYSQL_PWD=Netapp1!; mysql -e "DROP DATABASE wordpress;"'

$ kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- sh -c 'export MYSQL_PWD=Netapp1!; mysql -e "SHOW DATABASES;"'
Database
information_schema
mysql
performance_schema
sys
```
WHOOPSY ... I think I did it again...  

If you try to connect to the Wordpress UI, you will then see:
<p align="center"><img src="Images/ArgoCD_wordpress_broken.png" width="512"></p>

Let's try to restore lost data from one of our snapshots, in order to go back to a nominal state.  
Trident Protect allows to you to restore:
- in-place (to the source namespace)  
- to a different destination (same cluster or different cluster)  
- all the objects (full restore)  
- a subset of objects (partial restore)  

Let's restore the latest snapshot for the application _wordpress-mysql_, which contains what we need, ie the snapshot:  
```bash
$ tridentctl-protect create sir mysqlsir1 --snapshot wpargo1/custom-cc413-20250126161600 -n wpargo1
SnapshotInplaceRestore "mysqlsir1" created.

$ tridentctl-protect get sir -n wpargo1
+-----------+-------------+-----------+------+-------+
|   NAME    |  APPVAULT   |   STATE   | AGE  | ERROR |
+-----------+-------------+-----------+------+-------+
| mysqlsir1 | ontap-vault | Completed | 1m1s |       |
+-----------+-------------+-----------+------+-------+
```
Once done, you can see the PVC is restored, but the rest of the application is gone.  
This is expected, as to replace the PVC, the app had to be scaled down.  
```bash
$ kubectl get -n wpargo1 all,pvc -l tier=mysql
NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mysql-pvc   Bound    pvc-878d7606-5666-4459-b79a-704609348b53   20Gi       RWO            storage-class-nfs   <unset>                 83s
```
If you check ArgoCD, you can see that the wordpress tile is back to _OutOfSync_:  
<p align="center"><img src="Images/ArgoCD_wordpress_create_missing.png" width="384"></p>

If you press on the _Sync_ button, ArgoCD will redeploy the whole application on top of the PVC:  

```bash
$ kubectl get -n wpargo1 all,pvc -l tier=mysql
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                   READY   STATUS    RESTARTS   AGE
pod/wordpress-mysql-5d8b966d55-cjh5p   1/1     Running   0          11s

NAME                      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/wordpress-mysql   ClusterIP   None         <none>        3306/TCP   11s

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wordpress-mysql   1/1     1            1           11s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/wordpress-mysql-5d8b966d55   1         1         1       11s

NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mysql-pvc   Bound    pvc-878d7606-5666-4459-b79a-704609348b53   20Gi       RWO            storage-class-nfs   <unset>                 3m47s
```

Next, you can also verify that the **mysql** database is back:  
```bash
$ kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- sh -c 'export MYSQL_PWD=Netapp1!; mysql -e "SHOW DATABASES;"'
Database
information_schema
mysql
performance_schema
sys
wordpress
```
Last, if you refresh the browser, Wordpress will be back on its feet, with the blog you created earlier. 


<!-- NOTES

# How to copy the mysql.sh script from the host to the mysql pod and make it writable
kubectl cp ./mysql.sh wpargo1/$(kubectl get pod -n wpargo1 -l tier=mysql -o name | cut -d/ -f2):/tmp/mysql.sh
kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- chmod +x /tmp/mysql.sh

# How to manually run the hook script
kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- \
  sh -c 'MYSQL_ROOT_PASSWORD=Netapp1! /tmp/mysql.sh post'

# How to display the PROCESSLIST table
kubectl exec -n wpargo1 $(kubectl get pod -n wpargo1 -l tier=mysql -o name) -- sh -c 'export MYSQL_PWD=Netapp1!; mysql -e "SHOW PROCESSLIST;"'

# How to display if Trident Protect finds a match for all ExecHooksRun
kubectl get exechooksrun -n wpargo1 -o custom-columns='NAME:.metadata.name,APP:.spec.applicationRef,STATE:.status.state,AGE:.metadata.creationTimestamp,MATCHES:.status.conditions[0].message'

# How to delete all 4 apps in one command
argocd app delete -y trident-protect-wordpress-app wordpress

-->