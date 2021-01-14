#########################################################################################
# ADDENDA 10: Let's do some storage performance tests ! 
#########################################################################################

This page takes its sources in https://github.com/leeliu/dbench, app created by the company called LogDNA.  
However, the orginal image is not available on the Docker Hub. I have modified the definition to point to an alternative source.  
If this image also went to disappear, you can find in the DBench repository a Dockerfile to create your own image.  

The dbench.yaml contains 2 objects:

- a 100G PVC that uses the storage class _storage-class-nas_
- a Job that will create a POD to run FIO with several IO profiles

Feel free to modify it to use a different storage class or a volume of different size

```bash
$ kubectl create -f dbench.yaml
persistentvolumeclaim/dbench-pv-claim created
job.batch/dbench created
```

In order to see the results, you can use the following command:

```bash
$ kubectl logs -f jobs/dbench
#...
# plenty of details
#...
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 15.2k/10.1k. BW: 195MiB/s / 134MiB/s
Average Latency (usec) Read/Write: 749.46/728.47
Sequential Read/Write: 296MiB/s / 138MiB/s
Mixed Random Read/Write IOPS: 10.7k/3533
```

Finally, to clean up, you can simply do:

```bash
kubectl delete -f dbench.yaml
persistentvolumeclaim "dbench-pv-claim" deleted
job.batch "dbench" deleted
```
