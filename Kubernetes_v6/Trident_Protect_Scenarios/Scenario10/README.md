#########################################################################################
# SCENARIO 10: One bucket or two buckets, that is the question
#########################################################################################

Most of the scenarios are done with a single bucket, simply because it is easy to setup.  
As long as source and target environments have access to the same object store with reasonable latencies, then this could also be deployed in production.  

In some cases, you may want to consider using different objects stores:  
- if latency is too high or bandwidth too low between the secondary environment and the source bucket  
- because object stores can also have disruption (even if rare)  
- because your company policy or regulations require to use different providers

You probably could think of other reasons...  

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario10_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario10_pull_images.sh
```

## A. Second Bucket Creation

The goal here is not show you how to create a S3 Bucket in ONTAP.  
You can use the Ansible playbook you can find in the [Addend09](../../Addendum/Addenda09/).  

Note that you need the access and secret keys in order to configure an AppVault.  
Those keys are going to be available in the _/root/ansible_S3_SVM2_result.txt_ file.
```bash
ansible-playbook /root/LabNetApp/Kubernetes_v6/Addendum/Addenda09/svm2_S3_setup.yaml > /root/ansible_S3_SVM2_result.txt
```

## B. Secondary AppVault Preparation

Let's start by retrieving the bucket keys and create variables with their values:  
```bash
BUCKETKEY=$(grep "access_key" /root/ansible_S3_SVM2_result.txt | cut -d ":" -f 2 | cut -b 2- | sed 's/..$//')
BUCKETSECRET=$(grep "secret_key" /root/ansible_S3_SVM2_result.txt | cut -d ":" -f 2 | cut -b 2- | sed 's/..$//')
```

To create an AppVault, you need to create a secret that will contains those 2 keys.  
This must be done on the secondary cluster only. Notice the second command uses the _kubeconfig_ parameter:  
```bash
kubectl create secret generic -n trident-protect s3-2-creds --from-literal=accessKeyID=$BUCKETKEY --from-literal=secretAccessKey=$BUCKETSECRET --kubeconfig=/root/.kube/config_rhel5
```
The creation of the AppVault will happen in the next chapters of this scenario.  

As we are going to use several times the _aws_ tool to browse both buckets, we also need to update its _credentials_ file with the new bucket's keys:  
```bash
cat << EOF >> /root/.aws/credentials

[s3lod2]
aws_access_key_id = $BUCKETKEY
aws_secret_access_key = $BUCKETSECRET
EOF
```

## C. Application deployment  

We are going to setup our environment with Busybox.  
You can find the Yaml manifest in this folder:  
```bash
$ kubectl create -f busybox.yaml
namespace/tpsc10busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created
```
Let's check all is ok:  
```bash
$ kubectl get -n tpsc10busybox  po,pvc
NAME                          READY   STATUS    RESTARTS   AGE
pod/busybox-7f96d99bc-hj6z9   1/1     Running   0          91s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-101f439d-1a29-4c77-a0d2-403c2942fdab   1Gi        RWX            storage-class-nfs   <unset>                 2m5s
```
Last, let' write data in the PVC and check the result:  
```bash
$ kubectl exec -n tpsc10busybox $(kubectl get pod -n tpsc10busybox -o name) -- sh -c 'echo "bbox test for Scenario10!" > /data/file.txt'
$ kubectl exec -n tpsc10busybox $(kubectl get pod -n tpsc10busybox -o name) -- more /data/file.txt
bbox test for Scenario10!
```

## D. Define the application with Trident Protect

Next step, you need to define your application in Trident Protect.  
You have already done it a few times, you know how easy that is:  
```bash
$ tridentctl protect create app bbox --namespaces tpsc10busybox -n tpsc10busybox
Application "bbox" created.

$ tridentctl protect get app -n tpsc10busybox
+------+---------------+-------+-----+
| NAME |  NAMESPACES   | STATE | AGE |
+------+---------------+-------+-----+
| bbox | tpsc10busybox | Ready | 13s |
+------+---------------+-------+-----+
```

## E. Create a snapshot

Now, let's also create a snapshot.  
```bash
$ tridentctl protect create snapshot bboxsnap1 --app bbox --appvault ontap-vault -n tpsc10busybox
Snapshot "bboxsnap1" created.

$ tridentctl protect get snap -n tpsc10busybox
+-----------+------+----------------+-----------+-------+-----+
|   NAME    | APP  | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-----------+------+----------------+-----------+-------+-----+
| bboxsnap1 | bbox | Delete         | Completed |       | 11s |
+-----------+------+----------------+-----------+-------+-----+
```
Note that in production, you would also set up a _schedule_ to program snapshots creation.  
In this scenario, let's skip that part as we are demonstration bucket management.

Let's browse the primary buckets to check what we see with regards to that snapshot:  
```bash
$ SNAPPATH=$(kubectl -n tpsc10busybox get snapshot bboxsnap1 -o=jsonpath='{.status.appArchivePath}')
$ aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$SNAPPATH/
2025-06-18 16:05:06       1230 application.json
2025-06-18 16:05:06          3 exec_hooks.json
2025-06-18 16:05:15       2546 post_snapshot_execHooksRun.json
2025-06-18 16:05:14       2569 pre_snapshot_execHooksRun.json
2025-06-18 16:05:06       2516 resource_backup.json
2025-06-18 16:05:11       8312 resource_backup.tar.gz
2025-06-18 16:05:11       4686 resource_backup_summary.json
2025-06-18 16:05:15       4516 snapshot.json
2025-06-18 16:05:15        682 volume_snapshot_classes.json
2025-06-18 16:05:15       1877 volume_snapshot_contents.json
2025-06-18 16:05:15       2233 volume_snapshots.json
```

**Now that the setup is done, time to dive into the 2 following scenarios:**  
[1.](1_DisasterRecovery) Disaster Recovery with 2 buckets  
[2.](2_BackupRestore) Backup to bucket#1 & Restore from bucket#2  

