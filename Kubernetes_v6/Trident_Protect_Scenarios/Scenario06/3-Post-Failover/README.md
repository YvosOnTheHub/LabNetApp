#########################################################################################
# Post Failover hook
#########################################################################################

This hook can be used to customize your app in a **Failover** scenario.  
We will test this hook using the same scripts as in the previous scenario.  

If your namespace disappears, your whole Kubernetes cluster is broken or why not the whole site, you can use Trident Protect to failover your app on a secondary site. This allows minimum service downtime compared to a backup/restore methodology.  

By default, when failing over your app, it will restart on the secondary site with the same configuration as its nominal state.  
That said, the failed over app may need to be customized!  

In some cases, the image repository may be different on the second site, the number of replicas required may be different, etc...  
That is when this **post-failover** hook can help you, in order to automatically apply the necessary changes.

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
namespace/sc06bbox2 created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc06bbox2 deploy,pod,pvc
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/busybox   2/2     2            2           11m

NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-544f478c5b-5nzjc   1/1     Running   0          11m
pod/busybox-544f478c5b-hw5zr   1/1     Running   0          11m

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-ab99ef13-c0f4-4025-9ab5-6ccdf8aa62e8   1Gi        RWX            storage-class-nfs   <unset>                 11m
```

Now, let's look at the images used by this new app:
```bash
$ kubectl get pods -n sc06bbox2 -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{.spec.containers[0].image}{end}'; echo
busybox-544f478c5b-5nzjc:       registry.demo.netapp.com/busybox:site1
busybox-544f478c5b-hw5zr:       registry.demo.netapp.com/busybox:site1
```
We can see we are using images tagged with "site1".  

Always good to have some data for the demo:  
```bash
kubectl exec -n sc06bbox2 $(kubectl get pod -n sc06bbox2 -o name -l app=busybox) -- sh -c 'echo "bbox test with hooks!" > /data/file.txt'
kubectl exec -n sc06bbox2 $(kubectl get pod -n sc06bbox2 -o name -l app=busybox) -- more /data/file.txt
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
$ tridentctl protect create app sc06bbox2 --namespaces sc06bbox2 -n sc06bbox2
Application "sc06bbox2" created.

$ tridentctl protect create appvault OntapS3 sc06bbox2-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect
AppVault "sc06bbox1-vault" created.
```
Time to configure our 2 _post failover_ hooks:  
```bash
$ tridentctl protect create exechook bbox-replicas --action Failover --stage post --app sc06bbox2 --source-file hook-failover-replicas.sh --arg busybox --arg 1 -n sc06bbox2
ExecHook "bbox-replicas" created.

$ tridentctl protect create exechook bbox-tags --action Failover --stage post --app sc06bbox2 --source-file hook-failover-tag-rewrite.sh --arg site1 --arg site2 -n sc06bbox2
ExecHook "bbox-tags" created.

$ tridentctl protect get eh -n sc06bbox2
+---------------+-----------+-------+----------+-------+---------+-------+-------+
|     NAME      |    APP    | MATCH |  ACTION  | STAGE | ENABLED |  AGE  | ERROR |
+---------------+-----------+-------+----------+-------+---------+-------+-------+
| bbox-replicas | sc06bbox2 |       | Failover | Post  | true    | 1m17s |       |
| bbox-tags     | sc06bbox2 |       | Failover | Post  | true    | 17s   |       |
+---------------+-----------+-------+----------+-------+---------+-------+-------+
```
The setup is almost ready. We also need a snapshot:  
```bash
$ tridentctl protect create snapshot bboxsnap1 --app sc06bbox2 --appvault sc06bbox2-vault -n sc06bbox2
Snapshot "bboxsnap1" created.
```
 
We first need to add the appVault on the _secondary cluster_ to retrieve the app metadata during the failover process:  
```bash
tridentctl protect create appvault OntapS3 sc06bbox2-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect
```
Almost time to create the mirror relationship.  
This could be done with the _cli_, but for the sake of this scenario, let's use a YAML manifest.  
With that method, the namespace must be created beforehand:  
```bash
$ kubectl create ns sc06bbox2dr
namespace/sc06bbox2dr created
```
To initiate the relationship, we need to retrieve the app ID on the primary site, which is going to be used to enable the mirror.  
To make things easy, let's perform this on the primary site (we will use the kubeconfig of the secondary site):  
```bash
$ SRCAPPID=$(kubectl get application sc06bbox2 -o=jsonpath='{.metadata.uid}' -n sc06bbox2)

$ cat << EOF | kubectl apply --kubeconfig=/root/.kube/config_rhel5 -f -
apiVersion: protect.trident.netapp.io/v1
kind: AppMirrorRelationship
metadata:
  name: bboxamr1
  namespace: sc06bbox2dr
spec:
  desiredState: Established
  destinationAppVaultRef: sc06bbox2-vault
  namespaceMapping:
  - destination: sc06bbox2dr
    source: sc06bbox2
  recurrenceRule: |-
    DTSTART:20240901T000200Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  sourceAppVaultRef: sc06bbox2-vault
  sourceApplicationName: sc06bbox2
  sourceApplicationUID: $SRCAPPID
  storageClassName: sc-nfs
EOF
appmirrorrelationship.protect.trident.netapp.io/bboxamr1 created

$ kubectl get --kubeconfig=/root/.kube/config_rhel5 amr -n sc06bbox2dr
NAME       DESIRED STATE   STATE         ERROR   AGE
bboxamr1   Established     Established           2m
```
If you connect to the ONTAP system, you will see a new snapmirror relationship setup:  
```bash
cluster1::> snapmirror show
                                                                       Progress
Source            Destination Mirror  Relationship   Total             Last
Path        Type  Path        State   Status         Progress  Healthy Updated
----------- ---- ------------ ------- -------------- --------- ------- --------
nassvm:trident_pvc_ab99ef13_c0f4_4025_9ab5_6ccdf8aa62e8
            XDP  svm_secondary:trident_pvc_213d8964_dec7_41cc_9d7c_94cc0f41a53a
                              Snapmirrored
                                      Idle           -         true    -
```

Seeing that all is setup correctly, let's fail over the application.  
You can even delete the whole source namespace if you like!  
```bash
$ kubectl delete ns sc06bbox2
namespace "sc06bbox2" deleted
```
The following must be performed on the secondary site (it takes a couple of minutes to complete):  
```bash
$ kubectl patch amr bboxamr1 -n sc06bbox2dr --type=merge -p '{"spec":{"desiredState":"Promoted"}}'
appmirrorrelationship.protect.trident.netapp.io/bboxamr1 patched

$ tridentctl protect get amr -n sc06bbox2dr
+----------+-----------------+-----------------+---------------+----------+--------+-------+
|   NAME   |   SOURCE APP    | DESTINATION APP | DESIRED STATE |  STATE   |  AGE   | ERROR |
+----------+-----------------+-----------------+---------------+----------+--------+-------+
| bboxamr1 | sc06bbox2-vault | sc06bbox2-vault | Promoted      | Promoted | 12m49s |       |
+----------+-----------------+-----------------+---------------+----------+--------+-------+
```

As you can see, there is only **one replica** for the busybox pod! The first hook did its job.  
```bash
$ kubectl get -n sc06bbox2dr all,pvc
NAME                                         READY   STATUS    RESTARTS   AGE
pod/astra-hook-deployment-6478894f55-xz77s   1/1     Running   0          2m25s
pod/busybox-5cbb8b4cbf-76cwj                 1/1     Running   0          2m7s

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/astra-hook-deployment   1/1     1            1           2m25s
deployment.apps/busybox                 1/1     1            1           2m25s

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/astra-hook-deployment-6478894f55   1         1         1       2m25s
replicaset.apps/busybox-544f478c5b                 0         0         0       2m25s
replicaset.apps/busybox-5cbb8b4cbf                 1         1         1       2m7s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-213d8964-dec7-41cc-9d7c-94cc0f41a53a   1Gi        RWX            sc-nfs         <unset>                 13m
```
Now, let's check the image used by the busybox container.  
You will notice that the **tag is different** from the initial configuration, as expected per our second hook:   
```bash
$ kubectl get pods -l app=busybox -n sc06bbox2dr -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{.spec.containers[0].image}{end}'; echo
busybox-5cbb8b4cbf-76cwj:       registry.demo.netapp.com/busybox:site2
```

Both _restore_ hooks also write logs in a file located in the alpine pod folder /var/log/.  
This can be useful to debug or follow up all the tasks performed during the restore proces.  
```bash
$ kubectl exec -n sc06bbox2dr $(kubectl get po -n sc06bbox2dr -l app=alpine -o name) -- more /var/log/acc-logs-hooks.log
Thu Dec 19 09:15:17 UTC 2024: ========= HOOK REPLICAS SCALE START ===========
Thu Dec 19 09:15:17 UTC 2024: APP TO SCALE: busybox
Thu Dec 19 09:15:17 UTC 2024: NUMBER OF REPLICAS: 1
Thu Dec 19 09:15:17 UTC 2024: KUBERNETES DEPLOY NAME TO SCALE: busybox
Thu Dec 19 09:15:17 UTC 2024: ========= HOOK REPLICAS SCALE END ===========
Thu Dec 19 09:15:20 UTC 2024: ========= HOOK TAG REWRITE START ===========
Thu Dec 19 09:15:20 UTC 2024: PARAMETER1: site1
Thu Dec 19 09:15:20 UTC 2024: PARAMETER2: site2
Thu Dec 19 09:15:20 UTC 2024: OBJECT TO SWAP: deploy busybox: container 'busybox'
Thu Dec 19 09:15:21 UTC 2024:    INITIAL IMAGE: registry.demo.netapp.com/busybox:site1
Thu Dec 19 09:15:21 UTC 2024:    TARGET TAG: site2
Thu Dec 19 09:15:21 UTC 2024:    NEW IMAGE: registry.demo.netapp.com/busybox:site2
Thu Dec 19 09:15:21 UTC 2024: ========= HOOK TAG REWRITE END ===========
```
& voilà !