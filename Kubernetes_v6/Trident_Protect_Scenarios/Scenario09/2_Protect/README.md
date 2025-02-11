#########################################################################################
# SCENARIO 9.2: Let's give Pacman a hand
#########################################################################################

We will use Trident Protect to create:  
- a manual snapshot (ie on-demand)  
- a manual backup (ie on-demand)  
- a protection policy to automatically take consistent snapshots & backups  

If you have not yet created an AppVault, refer to the [Scenario03](../../Scenario03/) which guides you through the bucket provisioning as well as the AppVault (_ontap-vault_), which is created in the Trident Protect namespace, by the admin.  

We will create a Trident Protect application based on the pacman namespace, as well as a protection schedule:  
```bash
$ tridentctl protect create app pacman --namespaces pacman -n pacman
Application "pacman" created.

$ tridentctl protect get app -n pacman
+--------+------------+-------+-----+
|  NAME  | NAMESPACES | STATE | AGE |
+--------+------------+-------+-----+
| pacman | pacman     | Ready | 10s |
+--------+------------+-------+-----+

$ tridentctl protect create schedule --app pacman --granularity hourly --minute 10 --snapshot-retention 3 --backup-retention 3 --appvault ontap-vault -n pacman
Schedule "pacman-u9gzij" created.

$ tridentctl protect get schedule -n pacman
+---------------+--------+---------------+---------+-------+-----+-------+
|     NAME      |  APP   |   SCHEDULE    | ENABLED | STATE | AGE | ERROR |
+---------------+--------+---------------+---------+-------+-----+-------+
| pacman-u9gzij | pacman | Hourly:min=10 | true    |       | 52s |       |
+---------------+--------+---------------+---------+-------+-----+-------+
```
Last, you want to make sure the content of the database is flushed to the disk before taking a snapshot, especially if you have plenty of players!  
We can achieve that by creating pre/post snapshot hooks applied only on _mongo_ container:  
```bash
$ tridentctl protect create exechook hookpre --app pacman --action snapshot --stage pre --source-file ~/Verda/MongoDB/mongodb-hooks.sh --arg pre --match containerName:mongo -n pacman
ExecHook "hookpre" created.

$ tridentctl protect create exechook hookpost --app pacman --action snapshot --stage post --source-file ~/root~/Verda/MongoDB/mongodb-hooks.sh --arg post --match containerName:mongo -n pacman
ExecHook "hookpost" created.

$ tridentctl protect get exechook -n pacman
+----------+--------+-------+----------+-------+---------+-----+-------+
|   NAME   |  APP   | MATCH |  ACTION  | STAGE | ENABLED | AGE | ERROR |
+----------+--------+-------+----------+-------+---------+-----+-------+
| hookpost | pacman |       | Snapshot | Post  | true    | 23s |       |
| hookpre  | pacman |       | Snapshot | Pre   | true    | 43s |       |
+----------+--------+-------+----------+-------+---------+-----+-------+
```

There you go, Pacman is fully protected ! What an awesome little yellow ball!  

Before messing with him, let's create a manual snapshot & backup:  
```bash
$ tridentctl protect create snapshot pacsnap1 --app pacman --appvault ontap-vault -n pacman
Snapshot "pacsnap1" created.

$ tridentctl protect get snapshot -n pacman
+-----------------------------+---------+-----------+-------+-------+
|            NAME             | APP REF |   STATE   |  AGE  | ERROR |
+-----------------------------+---------+-----------+-------+-------+
| hourly-507f7-20250210171000 | pacman  | Completed | 2m35s |       |
| pacsnap1                    | pacman  | Completed | 21s   |       |
+-----------------------------+---------+-----------+-------+-------+

$ tridentctl protect create backup pacbkp1 --app pacman --snapshot pacsnap1 --appvault ontap-vault -n pacman
Backup "pacbkp1" created.

$ tridentctl protect get backup -n pacman
+-----------------------------+---------+-----------+-------+-------+
|            NAME             | APP REF |   STATE   |  AGE  | ERROR |
+-----------------------------+---------+-----------+-------+-------+
| hourly-507f7-20250210171000 | pacman  | Completed | 6m16s |       |
| pacbkp1                     | pacman  | Completed | 1m39s |       |
+-----------------------------+---------+-----------+-------+-------+
```
Your game's scores are now safe & sound.  

You may also want to configure a mirror of your app, just in case the whole primary cluster went down!  
As we will use a YAML manifest to do so, this requires creating manually a target namespace.  
You also need to first fetch the app ID, value that will be passed in the AMR (_ApplicationMirrorRelationship_) manifest.  
```bash
$ kubectl get application.protect.trident.netapp.io pacman -o=jsonpath='{.metadata.uid}' -n pacman
729e8acf-efbc-4690-aea2-d0da6c272a03

$ kubectl create --kubeconfig=/root/.kube/config_rhel5 ns pacmandr
namespace/pacmandr created

$ cat << EOF | kubectl apply --kubeconfig=/root/.kube/config_rhel5 -f -
apiVersion: protect.trident.netapp.io/v1
kind: AppMirrorRelationship
metadata:
  name: pacamr1
  namespace: pacmandr
spec:
  desiredState: Established
  destinationAppVaultRef: ontap-vault
  namespaceMapping:
  - destination: pacmandr
    source: pacman
  recurrenceRule: |-
    DTSTART:20240901T000200Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  sourceAppVaultRef: ontap-vault
  sourceApplicationName: pacman
  sourceApplicationUID: 729e8acf-efbc-4690-aea2-d0da6c272a03
  storageClassName: sc-nfs
EOF
appmirrorrelationship.protect.trident.netapp.io/pacamr1 created

$ tridentctl protect get amr -n pacmandr --context kub2-admin@kub2
+---------+-------------+-----------------+---------------+-------------+-------+-------+
|  NAME   | SOURCE APP  | DESTINATION APP | DESIRED STATE |    STATE    |  AGE  | ERROR |
+---------+-------------+-----------------+---------------+-------------+-------+-------+
| pacamr1 | ontap-vault | ontap-vault     | Established   | Established | 4m21s |       |
+---------+-------------+-----------------+---------------+-------------+-------+-------+
```
There you go. Pacman can be saved any time!  

Note that I used the resource name **application.protect.trident.netapp.io** instead of **application**.  
This is in case ArgoCD is installed, since it also has a resource called _application_ (_applications.argoproj.io_).

Let's break stuff in the [next chapter](../3_Restore)!  