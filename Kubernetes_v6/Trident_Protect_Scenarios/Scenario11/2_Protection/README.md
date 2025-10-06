#########################################################################################
# SCENARIO 11: Protecting Virtual Machines: Protection
#########################################################################################

This scenarion will guide you through the protection of the Alpine Virtual Machine, through snapshot creation and restore, as well as fail over the secondary cluster.

## A. Trident Protect Application definition

You already know that Trident can protect applications presented as namespaces, or grouped by labels.  
Protecting the whole *alpine* namespace would target unnecesary objects, such as the temporary launcher pod and the VMI, or even the secrets setup for the cloud init process.  

Let's apply the label **protect=yes** to the few objects that require protection (the PVC and the VM):  
```bash
kubectl label pvc alpine-boot-pvc "protect=yes" -n alpine
kubectl label pvc alpine-data-pvc "protect=yes" -n alpine
kubectl label vm alpine-vm "protect=yes" -n alpine
```

You can now define a new Trident application:  
```bash
$ tridentctl-protect create app alpine --namespaces 'alpine(protect=yes)' -n alpine
Application "alpine" created.
```

## B. Trident Protect Application snapshot

Time to create a snapshot of our application!  
```bash
$ tridentctl-protect create snapshot alpinesnap1 --app alpine --appvault ontap-vault -n alpine
Snapshot "alpinesnap1" created.

$ tridentctl-protect get snapshot  -n alpine
+-------------+--------+----------------+-----------+-------+-----+
|    NAME     |  APP   | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-------------+--------+----------------+-----------+-------+-----+
| alpinesnap1 | alpine | Delete         | Completed |       | 12s |
+-------------+--------+----------------+-----------+-------+-----+
```
As expected, you will also find a Volume Snapshot per PVC in the alpine namespace:  
```bash 
$ kubectl get -n alpine vs
NAME                                                                                     READYTOUSE   SOURCEPVC         SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
snapshot-2730899b-df0e-43c9-97f1-4e17633d932c-pvc-58ab7490-c473-4323-a5c1-fd7b6ad3191c   true         alpine-data-pvc                           1Gi           csi-snap-class   snapcontent-2d383f7c-5fd3-4862-8209-24772f490c94   36m            36m
snapshot-2730899b-df0e-43c9-97f1-4e17633d932c-pvc-c786e1a0-bbd6-4a3d-8e84-43f391376bd8   true         alpine-boot-pvc                           1Gi           csi-snap-class   snapcontent-8d2a064b-2096-4bd8-8056-cedf40a5c363   36m            36m
```

## C. Trident Protect Application snapshot restore

Your application is running in production, and you would like to test if the restore works.  
Or maybe you want to create a clone of your VM to perform other tasks...  

Let's create a **Snapshot Restore** operation with Trident to restore the VM in a different namespace called _alpinesr_:  
```bash 
$ tridentctl protect create sr alpinesr1 --namespace-mapping alpine:alpinesr --snapshot alpine/alpinesnap1 -n alpinesr
SnapshotRestore "alpinesr1" created.

$ tridentctl protect get sr -n alpinesr
+-----------+-------------+-----------+-------+-----+
|   NAME    |  APPVAULT   |   STATE   | ERROR | AGE |
+-----------+-------------+-----------+-------+-----+
| alpinesr1 | ontap-vault | Completed |       | 16s |
+-----------+-------------+-----------+-------+-----+
```
Very quickly, you will find the PVC and VM objects restored.  
In order to start an instance of the VM, you will notice that KubeVirt also launches temporary resources (pod & vmi):  
```bash
$ kubectl -n alpinesr get all,pvc
NAME                                READY   STATUS    RESTARTS   AGE
pod/virt-launcher-alpine-vm-rbj22   2/2     Running   0          41s

NAME                                           AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-vm   41s   Running   192.168.26.31   rhel1      True

NAME                                   AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-vm   41s   Running   True

NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-pvc   Bound    pvc-3b466e89-78e4-4947-9aca-7f2c71fb596b   1Gi        RWX            storage-class-iscsi   <unset>                 42s
persistentvolumeclaim/alpine-data-pvc   Bound    pvc-2d76ae90-783c-4790-b542-5342a5cc710d   1Gi        RWX            storage-class-iscsi   <unset>                 42s
```
It takes a couple of tens of seconds for the VM to boot, at which point you can connect to it, either via _virtctl_:  
```bash
$ virtctl console alpine-vm -n alpinesr
...
Welcome to Alpine Linux 3.22
Kernel 6.12.38-0-virt on x86_64 (/dev/ttyS0)

alpine-vm.alpinesr.svc.cluster.local login:
```
or by using _SSH_ with the same key setup for the initial VM:  
```bash
ALPINE_IP_SR=$(kubectl get vmi -n alpinesr alpine-vm -o jsonpath='{.status.interfaces[0].ipAddress}') && echo $ALPINE_IP_SR
ssh alpine@$ALPINE_IP_SR -i /root/.ssh/alpine
```
Either way, you can check the content of the VM:  
```bash
alpine-vm:~$ ls -l /data/alpine.txt
-rw-r--r--    1 alpine   alpine          23 Oct  5 19:42 /data/alpine.txt
alpine-vm:~$ more /data/alpine.txt
this is my alpine test
```
There you go. Snapshot Restore successful !

## D. Trident Protect Application Mirror Relationship

Our VM is protected locally, ie within the same Kubernetes cluster.  
Let's also enable cross cluster protection.  

Creating an AMR with Trident requires to know the source app UUID beforehand:  
```bash
$ SRCAPPID=$(kubectl get application alpine -n alpine -o=jsonpath='{.metadata.uid}') && echo $SRCAPPID

$ tridentctl-protect create amr alpineamr1 --source-app alpine --source-app-id $SRCAPPID \
  --source-app-vault ontap-vault --destination-app-vault ontap-vault \
  --namespace-mapping alpine:alpinedr --storage-class sc-iscsi \
  --recurrence-rule "DTSTART:20220101T000200Z\nRRULE:FREQ=MINUTELY;INTERVAL=5" \
  -n alpinedr --context kub2-admin@kub2
```
After a few seconds, the replication should be in the _established_ state:  
```bash
$ tridentctl-protect get amr -n alpinedr --context kub2-admin@kub2
+------------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-----+
|    NAME    | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |    STATE    | ERROR | AGE |
+------------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-----+
| alpineamr1 | alpine     | ontap-vault      | alpine          | ontap-vault           | Established   | Established |       | 46s |
+------------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-----+
```
You can see that the targe namespace currently only has the 2 PVC:  
```bash
$ kubectl get all,pvc -n alpinedr --kubeconfig=/root/.kube/config_rhel5
NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-pvc   Bound    pvc-55860dff-2840-422b-a863-32b77659627d   1Gi        RWX            sc-iscsi       <unset>                 1m
persistentvolumeclaim/alpine-data-pvc   Bound    pvc-3119b7f4-37f8-42cb-9491-fe971f1101ef   1Gi        RWX            sc-iscsi       <unset>                 1m
```

You may also want to check the replications available in the ONTAP system:  
```bash
cluster1::> snapmirror show
                                                                       Progress
Source            Destination Mirror  Relationship   Total             Last
Path        Type  Path        State   Status         Progress  Healthy Updated
----------- ---- ------------ ------- -------------- --------- ------- --------
sansvm:trident_pvc_58ab7490_c473_4323_a5c1_fd7b6ad3191c
            XDP  svm_secondary:trident_pvc_3119b7f4_37f8_42cb_9491_fe971f1101ef
                              Snapmirrored
                                      Idle           -         true    -
sansvm:trident_pvc_c786e1a0_bbd6_4a3d_8e84_43f391376bd8
            XDP  svm_secondary:trident_pvc_55860dff_2840_422b_a863_32b77659627d
                              Snapmirrored
                                      Idle           -         true    -
2 entries were displayed.
```
As expected, you have a SnapMirror relationship per PVC.  
The VM is now protected !

## E. Trident Protect Application Failover

To activate the target of the mirror relationship, you just need to modify the desired state to _promoted_:  
```bash
$ kubectl patch amr alpineamr1 -n alpinedr --type=merge -p '{"spec":{"desiredState":"Promoted"}}' --kubeconfig=/root/.kube/config_rhel5
appmirrorrelationship.protect.trident.netapp.io/alpineamr1 patched
```
It takes Trident a few seconds to complete the process: 
```bash
$ tridentctl-protect get amr -n alpinedr --context kub2-admin@kub2
+------------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+------+
|    NAME    | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |  STATE   | ERROR | AGE  |
+------------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+------+
| alpineamr1 | alpine     | ontap-vault      | alpine          | ontap-vault           | Promoted      | Promoted |       | 2m2s |
+------------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+------+
```
If you connect to ONTAP, you will also see that both SnapMirror relationships are gone.  

Let's see what we now have in the target namespace:  
```bash
$ kubectl get all,pvc -n alpinedr --kubeconfig=/root/.kube/config_rhel5
NAME                                READY   STATUS    RESTARTS   AGE
pod/virt-launcher-alpine-vm-86xxx   2/2     Running   0          76s

NAME                                           AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-vm   76s   Running   192.168.16.88   rhel5      True

NAME                                   AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-vm   76s   Running   True

NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-pvc   Bound    pvc-55860dff-2840-422b-a863-32b77659627d   1Gi        RWX            sc-iscsi       <unset>                 4m
persistentvolumeclaim/alpine-data-pvc   Bound    pvc-3119b7f4-37f8-42cb-9491-fe971f1101ef   1Gi        RWX            sc-iscsi       <unset>                 4m
```
It take an extra few seconds for the VM to boot. 
Use the following command to access the console:  
```bash
$ virtctl console alpine-vm -n alpinedr --context kub2-admin@kub2
...
Welcome to Alpine Linux 3.22
Kernel 6.12.38-0-virt on x86_64 (/dev/ttyS0)

alpine-vm.alpinesr.svc.cluster.local login: alpine

alpine-vm:~$ ls -l /data/alpine.txt
-rw-r--r--    1 alpine   alpine          23 Oct  5 19:42 /data/alpine.txt
alpine-vm:~$ more /data/alpine.txt
this is my alpine test
```
Tadaaa !! Failing over the VM on the secondary site was successful!  

Note that VM IP address is only accessible locally, ie on the nodes of the secondary cluster.  
If you are planning on using the SSH key, you would need to go through the host _rhel5_.