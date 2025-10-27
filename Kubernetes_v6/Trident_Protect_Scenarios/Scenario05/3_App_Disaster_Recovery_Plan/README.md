#########################################################################################
# SCENARIO 5: Tests scenario with Busybox: Disaster Recovery Plan
#########################################################################################  

You have seen how to protect your application and how to restore it in the previous chapter.  
We will see here:  
- how to configure a Disaster Recovery Plan (DR) for your application  
- how to failover your application  
- how to failback your application  

## A. DR setup  

Trident Protect already has the following set up on the source cluster:  
- Application  
- AppVault  
- Schedule (and a manual snapshot is already present)  

In order to enable the mirroring of our application, we need to perform 2 steps on the target K8S cluster (_RHEL5_):
- Make sure an AppVault exists on the target cluster (exact same configuration as the one on the source)  
- Create an AMR (AppMirrorRelationship) on the target cluster  

This will initiate the mirror relationship as well as its schedule.  

The DR of your application will be configured in the _tpsc05busyboxdr_ namespace.  
The App owner first needs access and rights on it before completing the setup.  
The script **creds_dr.sh** present in this folder will perform the following tasks for you as a Kubernetes admin:  
- create the tpsc05busyboxdr namespace on the secondary cluster  
- grant access to it for the _bbox-user_ by configuring a role & rolebinding  
- grant access to the AppVault to the _bbox-user_ on this namespace  

It must executed on the primary cluster (_RHEL3_ host).  

Time to reimpersonate the App owner once again.  
```bash
export KUBECONFIG=~/.kube/tpsc05-config
kubectl config use-context bbox-context-kub1
```

You can create the AMR with _tridentctl_, however we are going to use the CLI.  
We first need to retrieve the App ID on the _source_ cluster (cf parameter _sourceApplicationUID_ on the AMR):  
```bash
$ APPID=$(kubectl get application bbox -o=jsonpath='{.metadata.uid}' -n tpsc05busybox) && echo $APPID
7843511e-6665-4e5d-b7c0-6db66531c0ef
```
We can now use that value in the AMR creation on the _target_ cluster (you need to switch context for that).  
Note that when using a YAML manifest, the namespace must be present beforehand:  
```bash
$ kubectl config use-context bbox-context-kub2

$ cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: AppMirrorRelationship
metadata:
  name: bboxamr1
  namespace: tpsc05busyboxdr
spec:
  desiredState: Established
  destinationAppVaultRef: ontap-vault
  namespaceMapping:
  - destination: tpsc05busyboxdr
    source: tpsc05busybox
  recurrenceRule: |-
    DTSTART:20240901T000200Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  sourceAppVaultRef: ontap-vault
  sourceApplicationName: bbox
  sourceApplicationUID: $APPID
  storageClassName: sc-nfs
EOF
appmirrorrelationship.protect.trident.netapp.io/bboxamr1 created
```
After a few seconds, you will see the following (the AMR state will switch from _Establishing_ to _Established_):
```bash
$ tridentctl-protect get amr -n tpsc05busyboxdr --context bbox-context-kub2
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |    STATE    | ERROR |  AGE  |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
| bboxamr1 | bbox       | ontap-vault      | bbox            | ontap-vault           | Established   | Established |       | 9m45s |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
```
Logging into ONTAP, you can then see that there is a SnapMirror relationship per PVC available:  
```bash
cluster1::> snapmirror  show
                                                                       Progress
Source            Destination Mirror  Relationship   Total             Last
Path        Type  Path        State   Status         Progress  Healthy Updated
----------- ---- ------------ ------- -------------- --------- ------- --------
nassvm:trident_pvc_59f8f988_306c_4c3b_ae57_41d3cfe23dd3
            XDP  svm_secondary:trident_pvc_8063c9f4_c76b_455f_b97d_3ab3f8c2e6e1
                              Snapmirrored
                                      Idle           -         true    -
nassvm:trident_pvc_a4690e4c_89a4_4c9e_a88a_24d47474d3a9
            XDP  svm_secondary:trident_pvc_07160b8f_c20a_4b3b_8ecf_3598a7acd4f6
                              Snapmirrored
                                      Idle           -         true    -
2 entries were displayed.
```
Last, you also see 2 new volumes in the target namespace:  
```bash
$ kubectl get -n tpsc05busyboxdr pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
mydata1   Bound    pvc-75c144a7-4661-4972-b243-a85f2200d6b1   1Gi        RWX            sc-nfs         <unset>                 24m
mydata2   Bound    pvc-488e9ae2-6a1b-4ea1-b2f0-4b4a2a252271   1Gi        RWX            sc-nfs         <unset>                 24m
```

## B. Fail over your application  

You can activate your failover for a test (while leaving the app on the source cluster), or you can also simulate a real issue.  
In this scenario, we will delete the whole app.  

As the App owner does not have the credentials to delete the whole namespace, we will just delete the PVC & pods.  
```bash
$ kubectl config use-context bbox-context-kub1

$ kubectl delete deploy busybox && kubectl delete pvc --all
deployment.apps "busybox" deleted
persistentvolumeclaim "mydata1" deleted
persistentvolumeclaim "mydata2" deleted
``` 
> "HOLALALALA, my application is gone !!!!"  
> "no, need to panic, we have a plan for such event!"  

Let's not wait anymore & fail over our app to the **target cluster**.  
This can simply be achieved by changing the state of the AMR CR on the _target_ cluster.  
You will see that the AMR state will switch from _Promoting_ to _Promoted_.  
```bash
$ kubectl config use-context bbox-context-kub2

$ kubectl patch amr bboxamr1 -n tpsc05busyboxdr --type=merge -p '{"spec":{"desiredState":"Promoted"}}'
appmirrorrelationship.protect.trident.netapp.io/bboxamr1 patched

$ tridentctl-protect get amr -n tpsc05busyboxdr --context bbox-context-kub2
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+--------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |  STATE   | ERROR |  AGE   |
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+--------+
| bboxamr1 | bbox       | ontap-vault      | bbox            | ontap-vault           | Promoted      | Promoted |       | 15m11s |
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+--------+
```
Time to verify that our application is back in its feet!  
```bash
$ kubectl get -n tpsc05busyboxdr pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-4rq5d   1/1     Running   0          56s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-75c144a7-4661-4972-b243-a85f2200d6b1   1Gi        RWX            sc-nfs         <unset>                 2m36s
persistentvolumeclaim/mydata2   Bound    pvc-488e9ae2-6a1b-4ea1-b2f0-4b4a2a252271   1Gi        RWX            sc-nfs         <unset>                 2m36s
```
Last, is the content of the PVC safe & sound ?  
```bash
$ kubectl exec -n tpsc05busyboxdr $(kubectl get pod -n tpsc05busyboxdr -o name) -- more /data1/file.txt
bbox test1 in folder data1!
$ kubectl exec -n tpsc05busyboxdr $(kubectl get pod -n tpsc05busyboxdr -o name) -- more /data2/file.txt
bbox test1 in folder data2!
```
Tadaa, here is a successful DR !

## C. Fail back your application

If your primary site is ready to host applications again, or if the test is done, you can move on to fail back to the initial state.  
This is done in several steps:  
- Reverse Resync: to bring back the data on the primary site   
- Promote the primary site and reverse the mirror direction  

First, we can clean up the AMR created previously on RHEL5, as we do not need it anymore:  
```bash
$ tridentctl-protect delete amr bboxamr1 -n tpsc05busyboxdr --context bbox-context-kub2
Successfully sent deletion request for resource bboxamr1
```
We can also add more data to the application volume, to showcase there is new content:  
```bash
kubectl exec -n tpsc05busyboxdr $(kubectl get pod -n tpsc05busyboxdr -o name) -- sh -c 'echo "added during failover in data1" >> /data1/test.txt'
kubectl exec -n tpsc05busyboxdr $(kubectl get pod -n tpsc05busyboxdr -o name) -- sh -c 'echo "added during failover in data2" >> /data2/test.txt'
```
In a real environment, you may want to create local _snapshots_ & maybe a _schedule_ if the application runs for a long period of time on the secondary system. For this scenario, we will only create one snapshot on the **secondary cluster* directly followed by the failback:  
```bash
$ tridentctl-protect create snapshot bboxdrsnap1 --app bbox --appvault ontap-vault -n tpsc05busyboxdr --context bbox-context-kub2
Snapshot "bboxdrsnap1" created.

$ tridentctl-protect get snapshot -n tpsc05busyboxdr --context bbox-context-kub2
+-------------+------+----------------+-----------+-------+-----+
|    NAME     | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-------------+------+----------------+-----------+-------+-----+
| bboxdrsnap1 | bbox | Delete         | Completed |       | 56s |
+-------------+------+----------------+-----------+-------+-----+
``` 

Let's create a mirror replication from the secondary platform to the primary one.  
As done previously, you need to retrieve the app ID on the **secondary** environment (cf parameter _sourceApplicationUID_ on the AMR).  
```bash
$ APPIDDR=$(kubectl get application bbox -n tpsc05busyboxdr -o=jsonpath='{.metadata.uid}') && echo $APPIDDR
38fac584-6cdf-4016-b451-ff088bf43cd0
```
We can now use that value in the AMR creation on the **primary** cluster:  
```bash
$ kubectl config use-context bbox-context-kub1

$ cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: AppMirrorRelationship
metadata:
  name: bboxamr2
  namespace: tpsc05busybox
spec:
  desiredState: Established
  destinationAppVaultRef: ontap-vault
  namespaceMapping:
  - destination: tpsc05busybox
    source: tpsc05busyboxdr
  recurrenceRule: |-
    DTSTART:20240901T000200Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  sourceAppVaultRef: ontap-vault
  sourceApplicationName: bbox
  sourceApplicationUID: $APPIDDR
  storageClassName: storage-class-nfs
EOF
appmirrorrelationship.protect.trident.netapp.io/bboxamr2 created
```
After a few seconds, you will see the following (the AMR state will switch from _Establishing_ to _Established_):
```bash
$ tridentctl-protect get amr -n tpsc05busybox --context bbox-context-kub1
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |    STATE    | ERROR |  AGE  |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
| bboxamr2 | bbox       | ontap-vault      | bbox            | ontap-vault           | Established   | Established |       | 2m23s |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
```
You can check in ONTAP that you see 2 new snapmirror relationships.  
Also, 2 new PVC are present on the _primary_ site:  
```bash 
$ kubectl get -n tpsc05busybox pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata1   Bound    pvc-05f61d03-1b6a-40eb-9b37-13527ca567fc   1Gi        RWX            storage-class-nfs   <unset>                 83s
mydata2   Bound    pvc-435a86fc-fbb4-4b93-95a0-fdfe2b94e2f6   1Gi        RWX            storage-class-nfs   <unset>                 83s
```

Before failing over the services, we will create one last snapshot on the **secondary** site for the final update.  
We will also need its path on the AppVault in order to retrieve its content on the other site:  
```bash
$ kubectl config use-context bbox-context-kub2

$ tridentctl-protect create shutdownsnapshot bboxdrlastsnap --app bbox --appvault ontap-vault -n tpsc05busyboxdr --context bbox-context-kub2
ShutdownSnapshot "bboxdrlastsnap" created.

$ tridentctl-protect get shutdownsnapshot  -n tpsc05busyboxdr --context bbox-context-kub2
+----------------+---------+-----------+-----+-------+
|      NAME      | APP REF |   STATE   | AGE | ERROR |
+----------------+---------+-----------+-----+-------+
| bboxdrlastsnap | bbox    | Completed | 34s |       |
+----------------+---------+-----------+-----+-------+

$ LASTSNAP=$(kubectl get shutdownsnapshot bboxdrlastsnap -n tpsc05busyboxdr -o=jsonpath='{.status.appArchivePath}' | awk -F '/' '{print $3}') && echo $LASTSNAP
20250107122548_bboxdrlastsnap_5fa90108-5870-4a07-aac0-1bd74b176a08
```
Time to bring the app online on the **primary** site by patching the AMR!  
```bash
$ kubectl config use-context bbox-context-kub1

$ kubectl patch amr bboxamr2 -n tpsc05busybox --type=merge -p="{\"spec\":{\"desiredState\":\"Promoted\",\"promotedSnapshot\":\"$LASTSNAP\"}}"
appmirrorrelationship.protect.trident.netapp.io/bboxamr2 patched

$ tridentctl-protect get amr -n tpsc05busybox --context bbox-context-kub1
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+-------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |  STATE   | ERROR |  AGE  |
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+-------+
| bboxamr2 | bbox       | ontap-vault      | bbox            | ontap-vault           | Promoted      | Promoted |       | 7m24s |
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+-------+
```
Let's verify that the app is up&running on the **primary** site and also that the content of our volumes is complete:  
```bash
$ kubectl get -n tpsc05busybox pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-844b9bfbb7-zs4pb   1/1     Running   0          15s

NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata1   Bound    pvc-05f61d03-1b6a-40eb-9b37-13527ca567fc   1Gi        RWX            storage-class-nfs   <unset>                 3m49s
persistentvolumeclaim/mydata2   Bound    pvc-435a86fc-fbb4-4b93-95a0-fdfe2b94e2f6   1Gi        RWX            storage-class-nfs   <unset>                 3m49s

$ kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- more /data1/file.txt
bbox test1 in folder data1!
added during failover in data1

$ kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- more /data2/file.txt
bbox test1 in folder data2!
added during failover in data2
```
Tadaaa !

Going back to a full nominal state also means reconfiguring mirroring from the _primary_ to the _secondary_.  
That means, recreating a snapshot & a schedule on the **primary** site. We will also delete the second AMR:  
```bash
$ tridentctl-protect delete amr bboxamr2 -n tpsc05busybox --context bbox-context-kub1
Successfully sent deletion request for resource bboxamr2

$ tridentctl-protect create snapshot bboxsnap2 --app bbox --appvault ontap-vault -n tpsc05busybox --context bbox-context-kub1
Snapshot "bboxsnap2" created.

$ tridentctl-protect create schedule bbox-sched2 --appvault ontap-vault --app bbox --granularity hourly --minute 5 -n tpsc05busybox --context bbox-context-kub1
Schedule "bbox-sched2" created.
```
Before moving to the new AMR, we need again to retrieve the app ID on the _primary_ cluster:  
```bash
$ APPID=$(kubectl get application bbox -o=jsonpath='{.metadata.uid}' -n tpsc05busybox) && echo $APPID
851c6f30-4c6d-4d00-8cdd-4b311e41aa22
```

We can now use that value in the AMR creation on the _target_ cluster.  
As we have not cleaned up the DR namespace, no need to create a namespace in our case:  
```bash
$ kubectl config use-context bbox-context-kub2

$ cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: AppMirrorRelationship
metadata:
  name: bboxamr3
  namespace: tpsc05busyboxdr
spec:
  desiredState: Established
  destinationAppVaultRef: ontap-vault
  namespaceMapping:
  - destination: tpsc05busyboxdr
    source: tpsc05busybox
  recurrenceRule: |-
    DTSTART:20240901T000200Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  sourceAppVaultRef: ontap-vault
  sourceApplicationName: bbox
  sourceApplicationUID: $APPID
  storageClassName: sc-nfs
EOF
appmirrorrelationship.protect.trident.netapp.io/bboxamr3 created

$ tridentctl-protect get amr -n tpsc05busyboxdr --context bbox-context-kub2
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |    STATE    | ERROR |  AGE  |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
| bboxamr3 | bbox       | ontap-vault      | bbox            | ontap-vault           | Established   | Established |       | 1m45s |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
```

voilà, the loop is complete!
