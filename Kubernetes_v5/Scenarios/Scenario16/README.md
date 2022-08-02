#########################################################################################
# SCENARIO 16: Dealing with performance & ONTAP
#########################################################################################

The [Scenario08](../Scenario08) describes how to manage how storage is used, as in _capacity_.  
Trident 21.01 introduced the support of QoS Policy Groups for ONTAP, under 2 forms:  

- **Policy Group**: set a minimum &/or maximum throughput in IOPS or bandwidth (example: Minimum 100IOPS & Maximum 1000 IOPS per volume)
- **Adaptive Policy Group**: same as above, however, the policy is defined per capacity (example: Minimum 100IOPS per volume per TB)
 
The QoS feature was introduced in ONTAP 9.8, which is the version running in this lab.  

Setting this feature is not the exciting part of this scenario. You actually want to see it working!  
I am using here an application called _dbench_ which includes FIO (a standard performance script).  
This can be useful for some use cases, such as testing QoS. However, I would not necessarily recommend it to test the maximum performance a storage platform can provide, as it involves many different parameters (node size, number of threads, network ports, etc ...).  

You can learn more about DBench here: https://github.com/leeliu/dbench, app created by the company called LogDNA.  
However, the orginal image is not available on the Docker Hub. I have modified the definition to point to an alternative source.  
If this image also went to disappear, you can find in the DBench repository a Dockerfile to create your own image.  

## A. Set up the environment

Let's start by creating 3 different policies through REST API calls or ONTAP CLI:

- Policy Group#1: Maximum Throughput = 500 IOPS
- Policy Group#2: Maximum Throughput = 100 MBps
- Adaptive Policy Group: Peak = 50 IOPS / GB (which is 51200 IOPS / TB)

```bash
$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "fixed": {
    "capacity_shared": false,
    "max_throughput_iops": 500
  },
  "name": "QoS_500iops",
  "svm": {
    "name": "nfs_svm",
    "uuid": "2829ebfb-4d6a-11e8-a5dc-005056b08451"
  }
}' "https://cluster1.demo.netapp.com/api/storage/qos/policies"

$ curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "fixed": {
    "capacity_shared": false,
    "max_throughput_mbps": 100
  },
  "name": "QoS_100MBps",
  "svm": {
    "name": "nfs_svm",
    "uuid": "2829ebfb-4d6a-11e8-a5dc-005056b08451"
  }
}' "https://cluster1.demo.netapp.com/api/storage/qos/policies"

$ ssh 192.168.0.101 -l admin qos adaptive-policy-group create -policy-group aQoS -vserver nfs_svm -expected-iops 5IOPS/GB -peak-iops 50IOPS/GB -peak-iops-allocation allocated-space
```

Adaptive QoS allows you to set a rule on _allocated_ or _used_ space. I chose _allocated space_ in order to better reflect the results we will get with DBench.  
Let's make sure the 3 policies were indeed created:

```bash
$ curl -X GET -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/qos/policies" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "8bfdebbb-6605-11eb-b732-005056a46cf7",
      "name": "QoS_500iops"
    },
    {
      "uuid": "d6cc3f56-6603-11eb-b732-005056a46cf7",
      "name": "QoS_100MBps"
    },
    {
      "uuid": "dbafb8b4-6603-11eb-b732-005056a46cf7",
      "name": "aQoS"
    }
  ],
  "num_records": 3
}
```

For the benchmark, I am going to use one Trident Backend (Virtual Storage Pool with 3 differents pools) & 3 different storage classes.

```bash
$ kubectl create -n trident -f backend_vsp_qos.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-qos created

$ kubectl create -f sc_qos.yaml
storageclass.storage.k8s.io/sc-qos1 created
storageclass.storage.k8s.io/sc-qos2 created
storageclass.storage.k8s.io/sc-qos3 created
```

## B. Baseline

The next step consists in running a baseline with a RWX/NFS volume.

```bash
$ kubectl create -f dbench_baseline.yaml
persistentvolumeclaim/dbench-pvc-baseline created
job.batch/dbench created
```

In order to see the results of this test, you can read the logs of the dbench job that is currently running.
Note that it takes a few minutes for the benchmark to complete, however you can read its output in a live manner.

```bash
$ kubectl logs -f jobs/dbench-baseline
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 15.3k/10.9k. BW: 195MiB/s / 128MiB/s
Average Latency (usec) Read/Write: 785.78/704.16
Sequential Read/Write: 246MiB/s / 136MiB/s
Mixed Random Read/Write IOPS: 10.4k/3433
```

When the job is complete, you can delete it with the following command:

```bash
$ kubectl delete -f dbench_baseline.yaml
persistentvolumeclaim "dbench-pvc-baseline" deleted
job.batch "dbench-baseline" deleted
```

## C. Using the first policy group (Maximum Throughput = 500 IOPS)

We will first start with a 100GB volume.

```bash
$ kubectl create -f dbench_qos1_100G.yaml
persistentvolumeclaim/dbench-pvc-qos1 created
job.batch/dbench-qos1 created

$ kubectl logs -f jobs/dbench-qos1
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 495/495. BW: 31.4MiB/s / 31.4MiB/s
Average Latency (usec) Read/Write: 8002.64/8008.70
Sequential Read/Write: 30.1MiB/s / 31.6MiB/s
Mixed Random Read/Write IOPS: 374/120

$ kubectl delete -f dbench_qos1_100G.yaml
persistentvolumeclaim "dbench-pvc-qos1" deleted
job.batch "dbench-qos1" deleted
```

As expected, the benchmark does not go above the limit that was assigned to the volume.  
Let's try with a bigger volume.

```bash
$ kubectl create -f dbench_qos1_200G.yaml
persistentvolumeclaim/dbench-pvc-qos1 created
job.batch/dbench-qos1 created

$ kubectl logs -f jobs/dbench-qos1
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 495/496. BW: 31.4MiB/s / 31.4MiB/s
Average Latency (usec) Read/Write: 8009.49/8008.97
Sequential Read/Write: 31.3MiB/s / 31.8MiB/s
Mixed Random Read/Write IOPS: 372/122

$ kubectl delete -f dbench_qos1_200G.yaml
persistentvolumeclaim "dbench-pvc-qos1" deleted
job.batch "dbench-qos1" deleted
```

The behavior is the same in both cases. Whatever size of the PVC, the QoS policy will correspond to the whole PVC.   

## D. Using the second policy group (Maximum Throughput = 100 MBps)

```bash
$ kubectl create -f dbench_qos2.yaml
persistentvolumeclaim/dbench-pvc-qos2 created
job.batch/dbench-qos2 created

$ kubectl logs -f jobs/dbench-qos2
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 16.4k/11.9k. BW: 100MiB/s / 100MiB/s
Average Latency (usec) Read/Write: 781.33/701.97
Sequential Read/Write: 100MiB/s / 101MiB/s
Mixed Random Read/Write IOPS: 11.4k/3690

$ kubectl delete -f dbench_qos2.yaml
persistentvolumeclaim "dbench-pvc-qos2" deleted
job.batch "dbench-qos2" deleted
```

Again, as expected, the benchmark stays in the limits positionned by the QoS Policy.  
If you were to use a bigger size volume, you would end up with the same benchmark results.  

## E. Using the adaptive policy group (Maximum Throughput = 50 IOPS/GB)

Let's first start with a 100GB volume.

```bash
$ kubectl create -f dbench_qos3_100G.yaml
persistentvolumeclaim/dbench-pvc-qos3 created
job.batch/dbench-qos3 created

$ kubectl logs -f jobs/dbench-qos3
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 4742/4742. BW: 256MiB/s / 143MiB/s
Average Latency (usec) Read/Write: 801.47/800.03
Sequential Read/Write: 300MiB/s / 107MiB/s
Mixed Random Read/Write IOPS: 3729/1264

$ kubectl delete -f dbench_qos3_100G.yaml
persistentvolumeclaim "dbench-pvc-qos3" deleted
job.batch "dbench-qos3" deleted
```

As we are using Adaptive QoS, doubling capacity should provide twice the IOPS.  
Let's run the same test with a 200GB volume.

```bash
$ kubectl create -f dbench_qos3_200G.yaml
persistentvolumeclaim/dbench-pvc-qos3 created
job.batch/dbench-qos3 created

$ kubectl logs -f jobs/dbench-qos3
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 9490/9489. BW: 251MiB/s / 138MiB/s
Average Latency (usec) Read/Write: 813.49/661.02
Sequential Read/Write: 250MiB/s / 146MiB/s
Mixed Random Read/Write IOPS: 7120/2369

$ kubectl delete -f dbench_qos3_200G.yaml
persistentvolumeclaim "dbench-pvc-qos3" deleted
job.batch "dbench-qos3" deleted
```

Point proven !