#########################################################################################
# Post Restore hook
#########################################################################################

This hook can be used to customize your app in a **Restore** scenario.  

When restoring an app, various choices are possible.  
You can restore on the same cluster, in a different one, perform a full restore or only a partial one.  
That said, the restored app may need to be customized!  

In some cases, the image repository may be different on the second site, the number of replicas required may be different, etc...  
That is when this **post-restore** hook can help you, in order to automatically apply the necessary changes.

As this lab comes with one image repository, in order to test the first hook easily, let's imagine an app (_busybox_) that uses images with different tags (_site1_ & _site2_) depending on the site where it runs.  
Also, this app runs on site1 with _2 replicas_, but should run with only _1 replica_ on the secondary site for minimal services. Changing the number of replicas will be done by a second hook.   

Let's first push both images to the local repository (with 2 different tags) after retrieving it from a public repo.  
You can use the _scenario06_wordpress_images.sh_ to do so:  
```bash
sh scenario06-images.sh
```

Let's start by deploying our app and wait a few second for it to be ready:  
```bash
$ kubectl create -f busybox.yaml
namespace/sc06bbox1 created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc06bbox1 deploy,pod,pvc
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/busybox   2/2     2            2           2m13s

NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-5498c89575-b2bcw   1/1     Running   0          2m13s
pod/busybox-5498c89575-zzqxc   1/1     Running   0          2m13s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-ba63571b-e4b7-48b8-a2d7-2c80cfde9ea9   1Gi        RWX            storage-class-nfs   <unset>                 2m50s
```

Now, let's look at the images used by this new app:
```bash
$ kubectl get pods -n sc06bbox1 -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{.spec.containers[0].image}{end}'; echo
busybox-5498c89575-b2bcw:       registry.demo.netapp.com/busybox:site1
busybox-5498c89575-zzqxc:       registry.demo.netapp.com/busybox:site1
```
We can see we are using images tagged with "site1".  

Always good to have some data for the demo:  
```bash
kubectl exec -n sc06bbox1 $(kubectl get pod -n sc06bbox1 -o name -l app=busybox) -- sh -c 'echo "bbox test with hooks!" > /data/file.txt'
kubectl exec -n sc06bbox1 $(kubectl get pod -n sc06bbox1 -o name -l app=busybox) -- more /data/file.txt
```

Both our hooks will run commands against the _kubectl_ command embedded in the alpine pod that runs in the same namespace.  
In order to avoid a security breach, this pod is associated to a service account that only allows operation within that namespace.  
```bash
$ kubectl create -f alpine-kubectl.yaml
serviceaccount/kubectl-ns-admin-sa created
rolebinding.rbac.authorization.k8s.io/kubectl-ns-admin-sa created
deployment.apps/astra-hook-deployment created
```
Before moving to Trident Protect, we also need to add a Service Account:  
```bash
$ kubectl create -f busybox-tp-sa.yaml
serviceaccount/protect-user-secret created
secret/protect-user-secret created
rolebinding.rbac.authorization.k8s.io/bbox-tenant-rolebinding created
```
Now, let's configure Trident Protect to take into account that application.  
For this scenario, no need to add a protection schedule as the goal is to showcase the integration with hooks:  
```bash
$ tridentctl-protect create app sc06bbox1 --namespaces sc06bbox1 -n sc06bbox1
Application "sc06bbox1" created.
```
If you have not yet create an AppVault, refer to the [Scenario03](../../Scenario03/) which guides you through the bucket provisioning as well as the AppVault (_ontap-vault_), which is created in the Trident Protect namespace, by the admin.  

Time to configure our 2 _post restore_ hooks:  
```bash
$ tridentctl-protect create exechook bbox-replicas --action Restore --stage post --app sc06bbox1 --source-file hook-restore-replicas.sh --arg busybox --arg 1 -n sc06bbox1
ExecHook "bbox-replicas" created.

$ tridentctl-protect create exechook bbox-tags --action Restore --stage post --app sc06bbox1 --source-file hook-restore-tag-rewrite.sh --arg site1 --arg site2 -n sc06bbox1
ExecHook "bbox-tags" created.

$ tridentctl-protect get eh -n sc06bbox1
+---------------+-----------+-------+---------+-------+---------+-------+-------+
|     NAME      |    APP    | MATCH | ACTION  | STAGE | ENABLED |  AGE  | ERROR |
+---------------+-----------+-------+---------+-------+---------+-------+-------+
| bbox-replicas | sc06bbox1 |       | Restore | Post  | true    | 1m17s |       |
| bbox-tags     | sc06bbox1 |       | Restore | Post  | true    | 17s   |       |
+---------------+-----------+-------+---------+-------+---------+-------+-------+
```
The setup is almost ready. We first need a snapshot & a backup:  
```bash
$ tridentctl-protect create snapshot bboxsnap1 --app sc06bbox1 --appvault ontap-vault -n sc06bbox1
Snapshot "bboxsnap1" created.

$ tridentctl-protect create backup bboxbkp1 --app sc06bbox1 --snapshot bboxsnap1 --appvault ontap-vault  -n sc06bbox1
Backup "bboxbkp1" created.
```

The remaining part of this scenarion must be processed on the _secondary cluster_ (RHEL5).  
Let's see what happens when you restore that app.  

We first need to add the appVault on this cluster to retrieve the backup ID:  
```bash
tridentctl-protect create appvault OntapS3 sc06bbox1-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect
BKPPATH=$(tridentctl-protect get appvaultcontent sc06bbox1-vault --app sc06bbox1 --show-resources backup --show-paths -n trident-protect | grep bboxbkp1  | awk -F '|' '{print $7}')
```
We finally can proceed with the restore:  
```bash
$ tridentctl-protect create br bboxbr1 --namespace-mapping sc06bbox1:sc06bbox1br --appvault sc06bbox1-vault -n sc06bbox1br \
  --storageclass-mapping storage-class-nfs:sc-nfs \
  --path $BKPPATH
BackupRestore "bboxbr1" created.

$ tridentctl-protect get backuprestore -n sc06bbox1br
+---------+-----------------+-----------+-------+-------+
|  NAME   |    APPVAULT     |   STATE   |  AGE  | ERROR |
+---------+-----------------+-----------+-------+-------+
| bboxbr1 | sc06bbox1-vault | Completed | 1m30s |       |
+---------+-----------------+-----------+-------+-------+
```
The process takes a few minutes to complete.  
As you can see, there is only **one replica** for the busybox pod! The first hook did its job.  
```bash
$ kubectl get -n sc06bbox1br all,pvc
NAME                                         READY   STATUS    RESTARTS   AGE
pod/astra-hook-deployment-6478894f55-2qxx4   1/1     Running   0          4m9s
pod/busybox-7b99cc5b54-cwlhg                 1/1     Running   0          3m47s

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/astra-hook-deployment   1/1     1            1           4m9s
deployment.apps/busybox                 1/1     1            1           4m9s

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/astra-hook-deployment-6478894f55   1         1         1       4m9s
replicaset.apps/busybox-5498c89575                 0         0         0       4m9s
replicaset.apps/busybox-7b99cc5b54                 1         1         1       3m47s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-ec347998-c6cb-4595-9243-862331e011fa   1Gi        RWX            sc-nfs         <unset>                 4m10s
```
Now, let's check the image used by the busybox container.  
You will notice that the **tag is different** from the initial configuration, as expected per our second hook:   
```bash
$ kubectl get pods -l app=busybox -n sc06bbox1br -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{.spec.containers[0].image}{end}'; echo
busybox-7b99cc5b54-cwlhg:       registry.demo.netapp.com/busybox:site2
```

Both _restore_ hooks also write logs in a file located in the alpine pod folder /var/log/.  
This can be useful to debug or follow up all the tasks performed during the restore proces.  
```bash
$ kubectl exec -n sc06bbox1br $(kubectl get po -n sc06bbox1br -l app=alpine -o name) -- more /var/log/acc-logs-hooks.log
Wed Dec 18 13:17:04 UTC 2024: ========= HOOK TAG REWRITE START ===========
Wed Dec 18 13:17:04 UTC 2024: PARAMETER1: site1
Wed Dec 18 13:17:04 UTC 2024: PARAMETER2: site2
Wed Dec 18 13:17:05 UTC 2024: OBJECT TO SWAP: deploy busybox: container 'busybox'
Wed Dec 18 13:17:05 UTC 2024:    INITIAL IMAGE: registry.demo.netapp.com/busybox:site1
Wed Dec 18 13:17:05 UTC 2024:    TARGET TAG: site2
Wed Dec 18 13:17:05 UTC 2024:    NEW IMAGE: registry.demo.netapp.com/busybox:site2
Wed Dec 18 13:17:05 UTC 2024: ========= HOOK TAG REWRITE END ===========
Wed Dec 18 13:17:09 UTC 2024: ========= HOOK REPLICAS SCALE START ===========
Wed Dec 18 13:17:09 UTC 2024: APP TO SCALE: busybox
Wed Dec 18 13:17:09 UTC 2024: NUMBER OF REPLICAS: 1
Wed Dec 18 13:17:09 UTC 2024: KUBERNETES DEPLOY NAME TO SCALE: busybox
Wed Dec 18 13:17:09 UTC 2024: ========= HOOK REPLICAS SCALE END ===========
```

& voilà !