#########################################################################################
# SCENARIO 24: Mirroring volumes: Disaster Recovery
#########################################################################################  

The scenario takes you through the setup of such configuration, as well as the activation of secondary volume.  
Here are the steps you will perform:  
- creation of a new Trident backend for both the source Kubernetes cluster & the target Kubernetes cluster  
- creation of a new storage class for both the source Kubernetes cluster & the target Kubernetes cluster  
- creation of an application on the source cluster  
- creation of the mirroring relationship between the 2 clusters  
- activation of the DR environment following a issue on the first cluster

Some requirements for this:  
- A second Kubernetes is of course needed: [Addenda12](../../Addendum/Addenda12/)  

(to help you go through all this requirement, you can the _setup_sc24_k8S.sh_ script in this folder).  

## A. Trident configuration

Let's create a new backend per Kubernetes cluster:  
```bash
$ kubectl create -f rhel3_scenario24_trident_config.yaml
secret/sc24-credentials created
tridentbackendconfig.trident.netapp.io/backend-tmr created
storageclass.storage.k8s.io/sc-mirror created

$ kubectl create --kubeconfig=/root/.kube/config_rhel5 -f rhel5_scenario24_trident_config.yaml
secret/sc24-credentials created
tridentbackendconfig.trident.netapp.io/backend-tmr created
storageclass.storage.k8s.io/sc-mirror created
```
Note that you can pass two optional parameters to a Trident backend:  
- _replicationPolicy_: existing policy to apply to the the replication relationship (default: _MirrorAndVault_)  
- _replicationSchedule_: existing schedule to apply to the replication relationship (default: empty)  

In this example, here are the 2 values set:  
- replicationPolicy: _MirrorAllSnapshots_
- replicationSchedule: 5 minutes (_5min_)

Also the storage class is _snapmirror enabled_ with the annotation: _trident.netapp.io/replication: "true"_.

## B. Application creation

This part is pretty easy.  
Let's bring in on the first cluster a Busybox deployment with one NFS PVC attached to it:  
```bash
$ kubectl create -f rhel3_busybox.yaml
namespace/sc24busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc24busybox pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-7ff78f8654-5cqw7   1/1     Running   0          9s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-164ab34a-a5a6-4333-bf1a-6f122b5198aa   1Gi        RWX            sc-mirror      <unset>                 12m
```
Let's create some content on the application volume:  
```bash
$ kubectl exec -n sc24busybox $(kubectl get pod -n sc24busybox -o name) -- sh -c 'echo "SnapMirror test!" > /data/test.txt'
$ kubectl exec -n sc24busybox $(kubectl get pod -n sc24busybox -o name) -- more /data/test.txt
SnapMirror test!
```

## C. Mirroring configuration

This part is done with a new CR called a **TridentMirrorRelationship** (_TMR_ in short).  

<p align="center"><img src="../Images/dr_highlevel_arch.png" width="768"></p>

Let's create a TMR on the first cluster.  
This object refers to the PVC to protect (PVC _mydata_ in this exercise).  
```bash
$ kubectl create -f rhel3_tmr.yaml
tridentmirrorrelationship.trident.netapp.io/busybox-mirror created
```
On the secondary cluster, we will now create 2 objects:
- a TMR that refers to the source volume  
- a PVC that will be the destination of the mirror relatioship  

This folder contains a script that will retrieve the internal volume name & customize the target TMR.  
The volume name is required in order to establish the SnapMirror relationship.  
```bash
$ sh rhel5_tmr.sh
namespace/sc24busybox created
tridentmirrorrelationship.trident.netapp.io/busybox-mirror created
```
Last, we can now create the volume:  
```bash
$ kubectl create -f rhel5_pvc.yaml --kubeconfig=/root/.kube/config_rhel5
persistentvolumeclaim/mydata created
```
After a few seconds, the SnapMirror relationship should be present. Let's check:  
```bash
$ curl -s -X GET -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/snapmirror/relationships" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "94d84307-5667-11ef-a235-0050568566d7",
      "source": {
        "path": "nassvm:tmr_pvc_164ab34a_a5a6_4333_bf1a_6f122b5198aa",
        "svm": {
          "name": "nassvm"
        }
      },
      "destination": {
        "path": "svm_secondary:tmr_pvc_74afee3e_0b61_4c00_ae18_fe092d963364",
        "svm": {
          "name": "svm_secondary"
        }
      },
      "state": "snapmirrored",
      "healthy": true
    }
  ],
  "num_records": 1
}
```

## D. Disaster Recovery in action

```bash
$ kubectl delete ns sc24busybox
namespace "sc24busybox" deleted
```
Holalalalala ! I just deleted my whole stateful app!! Did I lose the data ?? (of course not)  

We first need to  update the state the secondary TMR to _promoted_.  
Once done, we can redeploy the application on top of the volume.  
```bash
$ kubectl --kubeconfig=/root/.kube/config_rhel5 -n sc24busybox patch tmr busybox-mirror  --type=merge -p '{"spec":{"state":"promoted"}}'
tridentmirrorrelationship.trident.netapp.io/busybox-mirror patched

$ kubectl --kubeconfig=/root/.kube/config_rhel5 create -f rhel5_busybox.yaml
deployment.apps/busybox created

$ kubectl --kubeconfig=/root/.kube/config_rhel5 -n sc24busybox get pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-7ff78f8654-x9sjq   1/1     Running   0          40s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-74afee3e-0b61-4c00-ae18-fe092d963364   1Gi        RWX            sc-mirror      <unset>                 94m
```
Last thing to verify: what is the content of our PVC:  
```bash
$ kubectl --kubeconfig=/root/.kube/config_rhel5 exec -n sc24busybox $(kubectl --kubeconfig=/root/.kube/config_rhel5 get pod -n sc24busybox -o name) -- more /data/test.txt
SnapMirror test!
```
& voilà, you managed to test how to protect the data if an application & how to restart it on a different environment !

## E. Clean up

```bash
kubectl delete ns sc24busybox
kubectl delete ns sc24busybox --kubeconfig=/root/.kube/config_rhel5
kubectl delete -f rhel3_scenario24_trident_config.yaml
kubectl delete --kubeconfig=/root/.kube/config_rhel5 -f rhel5_scenario24_trident_config.yaml
```
