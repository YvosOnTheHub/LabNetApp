#########################################################################################
# Pre/Post Snapshot hook
#########################################################################################

Nothing better than a database to test hooks to create consistent snapshots.  
Here is a scenario that will guide you through the protection of PostgreSQL.  

We are going to use hooks provided by NetApp on the Verda repo. If not done yet, please clone it locally:  
```bash
git clone https://github.com/NetApp/Verda ~/Verda
```

As we are using the lab image registry, you can run the following script to pull & push the required image:  
```bash
sh scenario06_pull_images.sh
```

Also, you can find in this folder a _values_ YAML file that you can use to install a PostgreSQL customized for this scenario.  
One of the notable part of this file is the user configuration. To avoid managing the DB password, the DB will be passwordless (not recommended for production as you can imagine).  
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install pg bitnami/postgresql --version 15.5.32 -n pg --create-namespace -f pg_values.yaml
```
After a few seconds, you should get the following:  
```bash
$ kubectl get -n pg all,pvc
NAME                  READY   STATUS    RESTARTS   AGE
pod/pg-postgresql-0   1/1     Running   0          2m51s

NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/pg-postgresql      ClusterIP   10.104.100.22   <none>        5432/TCP   2m52s
service/pg-postgresql-hl   ClusterIP   None            <none>        5432/TCP   2m52s

NAME                             READY   AGE
statefulset.apps/pg-postgresql   1/1     2m52s

NAME                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/data-pg-postgresql-0   Bound    pvc-9a1b5ffb-6884-4372-a442-8290bc055761   8Gi        RWO            storage-class-iscsi   <unset>                 2m51s
```
Next step would be to create a new database & a new table for this scenario:  
```bash
kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -c "CREATE DATABASE demo;"
kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -d demo \
    -c "CREATE TABLE demo1 (id SERIAL PRIMARY KEY, comment VARCHAR(40) NOT NULL, time TIMESTAMP NOT NULL);"
```
Just to make sure you can actually access this table & write some data into, you can run:  
```bash
$ kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -d demo -c "INSERT INTO demo1(comment,time) VALUES ('data1', NOW());"
INSERT 0 1

$ kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -d demo -c "SELECT * FROM demo1;"

 id | comment |           time
----+---------+---------------------------
  1 | data1   | 2024-12-19 17:38:51.56268
(1 row)
```
Cool, as expected, it works without dealing with a password !

Next, in order for application owner to work with Trident Protect, you need to grant him with an extra role, through a service account:  
```bash
$ kubectl create -f pg_tp_sa.yaml
serviceaccount/protect-user-secret created
secret/protect-user-secret created
rolebinding.rbac.authorization.k8s.io/bbox-tenant-rolebinding created
```

Time to start configuring a new Trident Protect configuration, including **pre/post snapshots hooks**:  
```bash
$ tridentctl protect create app pg --namespaces pg -n pg
Application "pg" created.
$ tridentctl protect get app -n pg
+------+------------+-------+-----+
| NAME | NAMESPACES | STATE | AGE |
+------+------------+-------+-----+
| pg   | pg         | Ready | 7s  |
+------+------------+-------+-----+
```
If you have not yet create an AppVault, refer to the [Scenario03](../../Scenario03/) which guides you through the bucket provisioning as well as the AppVault (_ontap-vault_), which is created in the Trident Protect namespace, by the admin.  

Before moving to the application protection, we first need to create the snapshots hooks:  
```bash
$ tridentctl protect create exechook pg-snap-pre --action Snapshot --app pg --stage pre --source-file ~/Verda/PostgreSQL/postgresql.sh --arg pre --match containerName:postgresql -n pg
ExecHook "pg-snap-pre" created.

$ tridentctl protect create exechook pg-snap-post --action Snapshot --app pg --stage post --source-file ~/Verda/PostgreSQL/postgresql.sh --arg post --match containerName:postgresql -n pg
ExecHook "pg-snap-post" created.

$ tridentctl protect get exechook -n pg
+--------------+-----+--------------------------+----------+-------+---------+-----+-------+
|     NAME     | APP |          MATCH           |  ACTION  | STAGE | ENABLED | AGE | ERROR |
+--------------+-----+--------------------------+----------+-------+---------+-----+-------+
| pg-snap-post | pg  | containerName:postgresql | Snapshot | Post  | true    | 12s |       |
| pg-snap-pre  | pg  | containerName:postgresql | Snapshot | Pre   | true    | 19s |       |
+--------------+-----+--------------------------+----------+-------+---------+-----+-------+
```
Using hooks makes more sense when the database is actively used...  
Let's open a different terminal on the same host (or use _tmux_ to use multiple terminals on the same window), and copy/paste the following loop, which will add a new line to the database every second:  
```bash
i=2
while true; do
  kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -d demo -c "INSERT INTO demo1(comment,time) VALUES ('data$i', NOW());"
  i=$((++i))
  sleep 1
done
```
You can verify that is works by reading the content of the DB on the main terminal:  
```bash
$ kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -d demo -c "SELECT * FROM demo1;"
 id | comment |            time
----+---------+----------------------------
  1 | data1   | 2024-12-19 17:38:51.56268
  2 | data2   | 2024-12-20 08:33:16.074704
  3 | data3   | 2024-12-20 08:33:17.557322
  4 | data4   | 2024-12-20 08:33:19.268108
```

Everything is now setup to test snapshots!  
Let's create one of those. Note that display the _date_ before & after requesting the snapshot:  
```bash
$ date; tridentctl protect create snapshot pgsnap1 --app pg --appvault ontap-vault -n pg
Fri Dec 20 08:36:58 AM UTC 2024
Snapshot "pgsnap1" created.

$ tridentctl protect get snap -n pg
+---------+---------+-----------+-----+-------+
|  NAME   | APP REF |   STATE   | AGE | ERROR |
+---------+---------+-----------+-----+-------+
| pgsnap1 | pg      | Completed | 40s |       |
+---------+---------+-----------+-----+-------+
```

For the fun, let's look into the DB to see if there were any impact, you need to look around the time of the request (_08:36:58_ in my case)
```bash
$ kubectl exec -it pg-postgresql-0 -n pg -- psql -h pg-postgresql -U postgres -d demo -c "SELECT * FROM demo1;"
 174 | data174 | 2024-12-20 08:37:11.970425
 175 | data175 | 2024-12-20 08:37:13.361464
 176 | data176 | 2024-12-20 08:37:14.658271
 204 | data178 | 2024-12-20 08:37:18.659171
 205 | data179 | 2024-12-20 08:37:20.273033
 206 | data180 | 2024-12-20 08:37:21.668216
```
You can also notice that the entry _data177_ is missing!  

If you switch back to the terminal where the loop is running, you may see the following:  
> psql: error: connection to server at "pg-postgresql" (10.104.100.22), port 5432 failed: FATAL:  the database system is in recovery mode  
> command terminated with exit code 2

**Of course, in a real production environment, you would make sure that such errors do not happen by applying a better configuration to the database.**  
**Here, I purposely set the database with a minimum configuration in order to witness the pause.**  

Last, let's restore this snapshot to a new namespace & read the content (it should stop around _data176_, right?):  
```bash
$ tridentctl protect create sr pgsr1 --namespace-mapping pg:pgsr --snapshot pg/pgsnap1 -n pgsr
SnapshotRestore "pgsr1" created.

$ tridentctl protect get sr -n pgsr
+-------+-------------+-----------+-----+-------+
| NAME  |   APPVAULT  |   STATE   | AGE | ERROR |
+-------+-------------+-----------+-----+-------+
| pgsr1 | ontap-vault | Completed | 26s |       |
+-------+-------------+-----------+-----+-------+

$ kubectl get pod,pvc -n pgsr
NAME                  READY   STATUS    RESTARTS   AGE
pod/pg-postgresql-0   1/1     Running   0          49s

NAME                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/data-pg-postgresql-0   Bound    pvc-98c09a81-1ab8-475d-b322-3d5697536c24   8Gi        RWO            storage-class-iscsi   <unset>                 50s

$ kubectl exec -it pg-postgresql-0 -n pgsr -- psql -h pg-postgresql -U postgres -d demo -c "SELECT * FROM (SELECT * FROM demo1 ORDER BY id DESC LIMIT 3) AS temp ORDER BY id ASC;"
 id  | comment |            time
-----+---------+----------------------------
 170 | data170 | 2024-12-20 08:37:06.364045
 171 | data171 | 2024-12-20 08:37:07.868211
 172 | data172 | 2024-12-20 08:37:09.4694
(3 rows)
```

tada !

Some more useful information: 
- PostgreSQL changed the backup primitives in v15:  
  - _pg_start_backup_ became _pg_backup_start_  
  - _pg_stop_backup_ became _pg_backup_stop_  
- Here are some commands you can use if you log into the PostgreSQL pod:  
  - listing DB: \l
  - switching DB: \c demo
  - listing tables: \dt
