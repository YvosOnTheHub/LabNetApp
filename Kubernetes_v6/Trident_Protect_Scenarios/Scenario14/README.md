#########################################################################################
# SCENARIO 14: Fail over to an older snapshot
#########################################################################################

By default, promoting an AppMirrorRelationship brings the application online on the destination from the **most recently transferred** snapshot.  
This scenario follows the same Busybox story as [Scenario05](../Scenario05/): write data, snapshot it, change the data, snapshot again, then fail over.  
The difference is the recovery point. After the good copy has been replicated, the data is removed and a newer snapshot is transferred. The failover then promotes the **previous** snapshot.

The procedure is the one documented in [Fail over to an older snapshot using Trident Protect](https://docs.netapp.com/us-en/trident/trident-protect/trident-protect-failover-older-snapshot.html).

Promoting an older snapshot makes ONTAP delete every destination SnapMirror snapshot that is newer than the one you select. Those copies are no longer valid. The annotation `protect.trident.netapp.io/allow-promotion-with-older-snapshots=true` is how you accept that loss. Without it, Trident Protect refuses the promote and stays in `Promoting` with:

`The snapshot provided is invalid or older than the most recently transferred snapshot`

Prerequisites, already covered by the previous scenarios:

- Trident and Trident Protect on both Kubernetes clusters, with ONTAP backends peered for SnapMirror. Azure NetApp Files and other non-ONTAP backends are not supported.
- The AppVault `ontap-vault` on **both** clusters, pointing at the same bucket ([Scenario03](../Scenario03/)).
- Storage classes `storage-class-nfs` on the primary cluster and `sc-nfs` on the secondary cluster.
- A VolumeSnapshotClass, as created in [Scenario01](../Scenario01/).

Commands below run from the primary host (_RHEL3_). Secondary commands use `--kubeconfig=/root/.kube/config_rhel5` or `--context kub2-admin@kub2`.

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
The shell script *scenario14_pull_images.sh* pulls the Busybox image used here and pushes it to the local private registry:

```bash
sh scenario14_pull_images.sh
```

The three snapshots in this lab are:

| Snapshot | Content of `/data/file.txt` | Role |
| --- | --- | --- |
| `bboxsnap1` | the first line only | early copy, not used for the failover |
| `bboxsnap2` | both lines | the recovery point you promote |
| `bboxsnap3` | file removed | the newest transferred snapshot, the damaged copy |

## A. Deploy Busybox

```bash
$ kubectl create -f busybox.yaml
namespace/tpsc14busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n tpsc14busybox pod,pvc
NAME                          READY   STATUS    RESTARTS   AGE
pod/busybox-7f96d99bc-hj6z9   1/1     Running   0          48s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-101f439d-1a29-4c77-a0d2-403c2942fdab   1Gi        RWX            storage-class-nfs   <unset>                 48s
```

## B. First content, first snapshot

Write the initial line and check it:

```bash
$ kubectl exec -n tpsc14busybox $(kubectl get pod -n tpsc14busybox -o name) -- sh -c 'echo "bbox test1 - initial content" > /data/file.txt'
$ kubectl exec -n tpsc14busybox $(kubectl get pod -n tpsc14busybox -o name) -- more /data/file.txt
bbox test1 - initial content
```

Define the Trident Protect application, then take the first manual snapshot:

```bash
$ tridentctl-protect create app bbox --namespaces tpsc14busybox -n tpsc14busybox
Application "bbox" created.

$ tridentctl-protect get app -n tpsc14busybox
+------+---------------+-------+-----+
| NAME |  NAMESPACES   | STATE | AGE |
+------+---------------+-------+-----+
| bbox | tpsc14busybox | Ready | 13s |
+------+---------------+-------+-----+

$ tridentctl-protect create snapshot bboxsnap1 --app bbox --appvault ontap-vault -n tpsc14busybox
Snapshot "bboxsnap1" created.

$ tridentctl-protect get snapshot -n tpsc14busybox
+-----------+------+----------------+-----------+-------+-----+
|   NAME    | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-----------+------+----------------+-----------+-------+-----+
| bboxsnap1 | bbox | Delete         | Completed |       | 11s |
+-----------+------+----------------+-----------+-------+-----+
```

Wait until the state is `Completed` before continuing. A snapshot that is still running is not a valid recovery point.

## C. More data, second snapshot

Append the line you will want back after the failover, then snapshot again:

```bash
$ kubectl exec -n tpsc14busybox $(kubectl get pod -n tpsc14busybox -o name) -- sh -c 'echo "bbox test2 - good content to recover" >> /data/file.txt'
$ kubectl exec -n tpsc14busybox $(kubectl get pod -n tpsc14busybox -o name) -- more /data/file.txt
bbox test1 - initial content
bbox test2 - good content to recover

$ tridentctl-protect create snapshot bboxsnap2 --app bbox --appvault ontap-vault -n tpsc14busybox
Snapshot "bboxsnap2" created.

$ tridentctl-protect get snapshot -n tpsc14busybox
+-----------+------+----------------+-----------+-------+-----+
|   NAME    | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-----------+------+----------------+-----------+-------+-----+
| bboxsnap1 | bbox | Delete         | Completed |       | 4m  |
| bboxsnap2 | bbox | Delete         | Completed |       | 12s |
+-----------+------+----------------+-----------+-------+-----+
```

`bboxsnap2` is the point in time used in the promote step. Leave it in place. The product documentation asks for a snapshot schedule with `snapshotRetention` greater than 1 so that older copies survive. This lab keeps the same copies as three manual snapshots, which stay until you delete them.

## D. AppMirrorRelationship

The relationship is created on the **secondary** cluster, in a new namespace.  
The annotation is set at creation time. It can also be added later, just before the promote, with:

```bash
kubectl annotate appmirrorrelationship bboxamr1 -n tpsc14busyboxdr \
  protect.trident.netapp.io/allow-promotion-with-older-snapshots="true" \
  --kubeconfig=/root/.kube/config_rhel5
```

Create the namespace, read the source application UID, and apply the relationship. The recurrence is one minute so the transfer does not sit on a five-minute schedule:

```bash
$ kubectl create ns tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5
namespace/tpsc14busyboxdr created

$ APPID=$(kubectl get application bbox -n tpsc14busybox -o=jsonpath='{.metadata.uid}') && echo $APPID
7843511e-6665-4e5d-b7c0-6db66531c0ef

$ cat << EOF | kubectl apply --kubeconfig=/root/.kube/config_rhel5 -f -
apiVersion: protect.trident.netapp.io/v1
kind: AppMirrorRelationship
metadata:
  name: bboxamr1
  namespace: tpsc14busyboxdr
  annotations:
    protect.trident.netapp.io/allow-promotion-with-older-snapshots: "true"
spec:
  desiredState: Established
  destinationAppVaultRef: ontap-vault
  namespaceMapping:
  - destination: tpsc14busyboxdr
    source: tpsc14busybox
  recurrenceRule: |-
    DTSTART:20240901T000200Z
    RRULE:FREQ=MINUTELY;INTERVAL=1
  sourceAppVaultRef: ontap-vault
  sourceApplicationName: bbox
  sourceApplicationUID: $APPID
  storageClassName: sc-nfs
EOF
appmirrorrelationship.protect.trident.netapp.io/bboxamr1 created
```

There is no `tridentctl-protect` command that forces an AppMirrorRelationship to replicate immediately. Each cycle follows `spec.recurrenceRule`. On the destination, Trident Protect creates a `TridentActionMirrorUpdate` (`tamu`) for that cycle. That object updates the volume SnapMirror **and** the relationship copies the snapshot archive into the destination AppVault. Both parts are required before `spec.promotedSnapshot` can name that snapshot.

A `TridentActionMirrorUpdate` created by hand, as in Trident [Scenario24](../../Trident_Scenarios/Scenario24/2_Volume_Migration/), updates the volume mirror only. The application archive used by `spec.promotedSnapshot` is copied by the AppMirrorRelationship cycle. Let the relationship run that cycle.

Wait until the state is `Established` and a mirror update has succeeded. At this moment `bboxsnap2` is the newest snapshot, so this first cycle transfers the copy you will later promote:

```bash
$ tridentctl-protect get amr -n tpsc14busyboxdr --context kub2-admin@kub2
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |    STATE    | ERROR |  AGE  |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+
| bboxamr1 | bbox       | ontap-vault      | bbox            | ontap-vault           | Established   | Established |       | 1m20s |
+----------+------------+------------------+-----------------+-----------------------+---------------+-------------+-------+-------+

$ kubectl get tamu -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5
NAME                        NAMESPACE        STATE       COMPLETIONTIME
amu-a1b2c3d4-tmr-e5f6a7b8   tpsc14busyboxdr  Succeeded   35s

$ kubectl get pvc -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-75c144a7-4661-4972-b243-a85f2200d6b1   1Gi        RWX            sc-nfs         <unset>                 1m20s
```

The destination PVC is bound and empty of pods. The application stays on the source until the promote.

Continue once the relationship is `Established`, a `tamu` is `Succeeded`, and the destination PVC is bound. That first cycle transferred `bboxsnap2`, which is the newest snapshot at this point.

If you want to see the archive in the bucket, the folder name is the snapshot basename:

```bash
$ DRAPPID=$(kubectl get application bbox -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5 -o=jsonpath='{.metadata.uid}') && echo $DRAPPID
4faa60d0-d6be-4871-960f-b719788a25d6

$ aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/bbox_$DRAPPID/replicatedSnapshots/
                           PRE 20250618161000_bboxsnap2_27c105b9-f3d9-422c-8415-cb9aae208cbc/
```

## E. Remove the data, third snapshot

The source application is still running. Delete the file, confirm the volume is empty, and take a new snapshot. This is the damaged copy:

```bash
$ kubectl exec -n tpsc14busybox $(kubectl get pod -n tpsc14busybox -o name) -- rm -f /data/file.txt
$ kubectl exec -n tpsc14busybox $(kubectl get pod -n tpsc14busybox -o name) -- ls /data

$ tridentctl-protect create snapshot bboxsnap3 --app bbox --appvault ontap-vault -n tpsc14busybox
Snapshot "bboxsnap3" created.

$ tridentctl-protect get snapshot -n tpsc14busybox
+-----------+------+----------------+-----------+-------+-----+
|   NAME    | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-----------+------+----------------+-----------+-------+-----+
| bboxsnap1 | bbox | Delete         | Completed |       | 8m  |
| bboxsnap2 | bbox | Delete         | Completed |       | 4m  |
| bboxsnap3 | bbox | Delete         | Completed |       | 15s |
+-----------+------+----------------+-----------+-------+-----+
```

## F. Wait until the relationship transfers bboxsnap3

Promoting `bboxsnap2` is an older-snapshot failover only after a **newer** snapshot has been transferred. If you promote while `bboxsnap2` is still the latest transferred copy, you are failing over to the current copy.

Note the `COMPLETIONTIME` of the current `tamu`, then wait for the next one-minute cycle. A new `tamu` reaches `Succeeded` after `bboxsnap3` completed. The replicated-snapshot folder then also shows a `bboxsnap3` prefix:

```bash
$ kubectl get tamu -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5
NAME                        NAMESPACE        STATE       COMPLETIONTIME
amu-a1b2c3d4-tmr-e5f6a7b8   tpsc14busyboxdr  Succeeded   3m10s
amu-c3d4e5f6-tmr-a7b8c9d0   tpsc14busyboxdr  Succeeded   20s

$ DRAPPID=$(kubectl get application bbox -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5 -o=jsonpath='{.metadata.uid}')
$ aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/bbox_$DRAPPID/replicatedSnapshots/
                           PRE 20250618161000_bboxsnap2_27c105b9-f3d9-422c-8415-cb9aae208cbc/
                           PRE 20250618161400_bboxsnap3_9ac41e02-6b10-4e77-9d2a-11c0b7e4aa31/
```

## G. List the snapshots and record the bboxsnap2 basename

`tridentctl-protect get snapshot` lists the snapshot custom resources. `spec.promotedSnapshot` takes the basename of `status.appArchivePath`, which is the last element of the archive path. `tridentctl-protect get appvaultcontent --show-paths` prints that path:

```bash
$ tridentctl-protect get snapshot -n tpsc14busybox
+-----------+------+----------------+-----------+-------+-----+
|   NAME    | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-----------+------+----------------+-----------+-------+-----+
| bboxsnap1 | bbox | Delete         | Completed |       | 9m  |
| bboxsnap2 | bbox | Delete         | Completed |       | 5m  |
| bboxsnap3 | bbox | Delete         | Completed |       | 1m  |
+-----------+------+----------------+-----------+-------+-----+

$ tridentctl-protect get appvaultcontent ontap-vault --app bbox --show-resources snapshot --show-paths -n trident-protect
+---------+------+----------+-----------+---------------+-----------+---------------------------+---------------------------+--------------------------------------------------------------------------------------------------+
| CLUSTER | APP  |   TYPE   |   NAME    |   NAMESPACE   |   STATE   |          CREATED          |         COMPLETED         |                                               PATH                                               |
+---------+------+----------+-----------+---------------+-----------+---------------------------+---------------------------+--------------------------------------------------------------------------------------------------+
|         | bbox | snapshot | bboxsnap1 | tpsc14busybox | Completed | 2025-06-18 16:06:00 (UTC) | 2025-06-18 16:06:12 (UTC) | bbox_7843511e-6665-4e5d-b7c0-6db66531c0ef/snapshots/20250618160600_bboxsnap1_11111111-2222-3333-4444-555555555555 |
|         | bbox | snapshot | bboxsnap2 | tpsc14busybox | Completed | 2025-06-18 16:10:00 (UTC) | 2025-06-18 16:10:11 (UTC) | bbox_7843511e-6665-4e5d-b7c0-6db66531c0ef/snapshots/20250618161000_bboxsnap2_27c105b9-f3d9-422c-8415-cb9aae208cbc |
|         | bbox | snapshot | bboxsnap3 | tpsc14busybox | Completed | 2025-06-18 16:14:00 (UTC) | 2025-06-18 16:14:12 (UTC) | bbox_7843511e-6665-4e5d-b7c0-6db66531c0ef/snapshots/20250618161400_bboxsnap3_9ac41e02-6b10-4e77-9d2a-11c0b7e4aa31 |
+---------+------+----------+-----------+---------------+-----------+---------------------------+---------------------------+--------------------------------------------------------------------------------------------------+
```

Keep the basename of `bboxsnap2` (everything after the last `/`):

```bash
$ SNAP2=$(tridentctl-protect get appvaultcontent ontap-vault --app bbox --show-resources snapshot --show-paths -n trident-protect \
  | awk -F'|' '/bboxsnap2/{for(i=1;i<=NF;i++) if($i ~ /snapshots\//){gsub(/ /,"",$i); n=split($i,a,"/"); print a[n]; exit}}')
$ echo $SNAP2
20250618161000_bboxsnap2_27c105b9-f3d9-422c-8415-cb9aae208cbc
```

The same value is on the snapshot custom resource, which is the form shown in the product documentation:

```bash
$ kubectl get snapshot bboxsnap2 -n tpsc14busybox -o jsonpath='{.status.appArchivePath}' | awk -F '/' '{print $NF}'
20250618161000_bboxsnap2_27c105b9-f3d9-422c-8415-cb9aae208cbc
```

Use that basename. `bboxsnap2` alone is rejected.

## H. Promote the relationship to the second snapshot

On the destination cluster, set `desiredState` to `Promoted` and `promotedSnapshot` to the basename recorded above. The annotation from section D is already present:

```bash
$ kubectl patch amr bboxamr1 -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5 \
  --type=merge -p "{\"spec\":{\"desiredState\":\"Promoted\",\"promotedSnapshot\":\"$SNAP2\"}}"
appmirrorrelationship.protect.trident.netapp.io/bboxamr1 patched

$ tridentctl-protect get amr -n tpsc14busyboxdr --context kub2-admin@kub2
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+-------+
|   NAME   | SOURCE APP | SOURCE APP VAULT | DESTINATION APP | DESTINATION APP VAULT | DESIRED STATE |  STATE   | ERROR |  AGE  |
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+-------+
| bboxamr1 | bbox       | ontap-vault      | bbox            | ontap-vault           | Promoted      | Promoted |       | 6m12s |
+----------+------------+------------------+-----------------+-----------------------+---------------+----------+-------+-------+
```

If the state stays on `Promoting`, print the status and read `status.error`:

```bash
kubectl get amr bboxamr1 -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5 -o=jsonpath='{.status}' | jq
```

The usual causes are a missing annotation, a basename that is not the archive path, or a snapshot the relationship has not transferred yet.

The application is now running on the destination, from `bboxsnap2`. The file removed in `bboxsnap3` is back, including the second line:

```bash
$ kubectl get pod,pvc -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5
NAME                          READY   STATUS    RESTARTS   AGE
pod/busybox-7f96d99bc-4rq5d   1/1     Running   0          40s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-75c144a7-4661-4972-b243-a85f2200d6b1   1Gi        RWX            sc-nfs         <unset>                 6m

$ kubectl exec -n tpsc14busyboxdr --kubeconfig=/root/.kube/config_rhel5 \
  $(kubectl get pod -n tpsc14busyboxdr -o name --kubeconfig=/root/.kube/config_rhel5) -- more /data/file.txt
bbox test1 - initial content
bbox test2 - good content to recover
```

Tadaaa!

The source application keeps running. The Busybox pod on `tpsc14busybox` is still up, and its volume still has no `file.txt`. The recovered copy is the one in `tpsc14busyboxdr`.

Returning to the original cluster is a **reverse resync**, then a reversal of the replication direction. A normal resync (setting the relationship back to `Established`) discards the failed-over application and returns to the newest source snapshot. [Scenario05](../Scenario05/3_App_Disaster_Recovery_Plan/) walks through that failback, and the product documentation describes the same sequence after an older-snapshot failover.
