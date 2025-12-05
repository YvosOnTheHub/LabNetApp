#########################################################################################
# SCENARIO 28: Automated Workload Failover 
#########################################################################################

High availability is a complex topic when working with Kubernetes.  
Who has the responsibilty to maintain contuinity in case of a node failure?  
- The application itself?  
- Kubernetes?  
- The infrastructure team(s)?  

There is no simple answer there.  
That said, cloud-native applications _should_ be built to sustain a node failure, or even a complete orchestrator failure, and I am not even touching datacenter, zone or region issues...  

Coming back to Kubernetes, some mechanisms are embedded to deal with failure.  
If an issue with a worker node happens, Kubernetes will restart a pod on a different node after various checks and timeouts have passed.  

What about stateful applications? How does a node failure affect them?  
Mounting a storage resource creates a tight connectivity between a worker node and the storage platform. If a node fails, the connectivity still (virtully) exists. By default, nobody is going to tell the storage platform _hey, a node is gone, do something about it_... So the storage still considers the node to be present.  

You also know that the access mode configured in a PVC defines how many pods can mount a volume.  
But a side effect can also be observed in case of a node failure:  
- RWO: Kubernetes will restart a new pod, but as the PV mount point is not deleted, the POD will never reach 'running' status. 
- RWX: by definition, multiple pods can mount a volume. Even if an existing connectivity is not cleaned up, a new pod will be able to mount a PVC

Let's see that in action.
We will create 3 applications in a given namespace _scenario28_:  
- iSCSI PVC in RWO  
- NFS PVC in RWO  
- NFS PVC in RWX

We will first witness the default behavior when a node fails, and then configure the environment to act upon such failure.  

As automated workload failover is not functional (yet) with SMB, let's cordon the 2 Windows nodes:  
```bash
$ kubectl cordon win1 win2
node/win1 cordoned
node/win2 cordoned
```
Let's also disable scheduling on the control plane, so that we only can work on the hosts _rhel1_ and _rhel2_.  
```bash
kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule
```

Last, if you have not yet read the [Addenda08](../../Addendum/Addenda08/) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario28_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario28_pull_images.sh
```

## A. Standard behavior

In order to make sure the 3 apps start on the same node, let's _cordon_ one of them.  
Make sure to cordon the worker node where the Trident Controller is running (if it not running on the control plane).  
As the Automated Workloads Failover feature lives inside the Trident controller, if the node carrying that pod were to fail, you would first to manually reschedule the trident pod...
```bash
$ kubectl get -n trident po -l app=controller.csi.trident.netapp.io -o wide
NAME                                  READY   STATUS      RESTARTS   AGE     IP               NODE    NOMINATED NODE   READINESS GATES
trident-controller-6955d565dd-98ql2   6/6     Running     0          35m     192.168.28.109   rhel1   <none>           <none>

$ kubectl cordon rhel1
node/rhel1 cordoned

$ kubectl get node -l kubernetes.io/os=linux
NAME    STATUS                     ROLES           AGE    VERSION
rhel1   Ready,SchedulingDisabled   <none>          567d   v1.29.4
rhel2   Ready                      <none>          567d   v1.29.4
rhel3   Ready                      control-plane   567d   v1.29.4
```
With "schedule" disabled on the _rhel1_, the applications should start on _rhel2_:  
```bash
$ kubectl create ns scenario28
namespace/scenario28 created

$ kubectl create -f busybox_nfs_rwx.yaml -f busybox_nfs_rwo.yaml -f busybox_iscsi_rwo.yaml
persistentvolumeclaim/mydata-nfs-rwx created
deployment.apps/busybox-nfs-rwx created
persistentvolumeclaim/mydata-nfs-rwo created
deployment.apps/busybox-nfs-rwo created
persistentvolumeclaim/mydata-iscsi created
deployment.apps/busybox-iscsi created
```
After a few seconds, you will 3 new apps running on the node rhel2:  
```bash
$ kubectl get -n scenario28 pvc
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
mydata-iscsi     Bound    pvc-9b8e3df5-803b-48e0-8360-c69218e5d539   1Gi        RWO            storage-class-iscsi   <unset>                 27s
mydata-nfs-rwo   Bound    pvc-46ca00cc-da41-4ae2-a502-0b944764ddd4   1Gi        RWO            storage-class-nfs     <unset>                 27s
mydata-nfs-rwx   Bound    pvc-bf885a6d-dd7a-4921-afd2-26c777ef9d23   1Gi        RWX            storage-class-nfs     <unset>                 27s

$ kubectl get -n sc28busybox po -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
busybox-iscsi-86bf85d6b7-j5w5c     1/1     Running   0          33s   192.168.28.83   rhel2   <none>           <none>
busybox-nfs-rwo-5994dd85c5-2mhx5   1/1     Running   0          33s   192.168.28.82   rhel2   <none>           <none>
busybox-nfs-rwx-76488d5b4c-24cgn   1/1     Running   0          32s   192.168.28.71   rhel2   <none>           <none>
```
Let's also create some content in all three PVC:  
```bash
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-iscsi -o name) -- sh -c 'echo "test1!" > /data/test1.txt'
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-nfs-rwo -o name) -- sh -c 'echo "test2!" > /data/test2.txt'
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-nfs-rwx -o name) -- sh -c 'echo "test3!" > /data/test3.txt'
```
With our 3 pods running on rhel2, we can now _uncordon_ the other host. This is to allow the pods to eventually restart there:    
```bash
kubectl uncordon rhel1
```
The stage is set. Let's turn off the host _rhel2_.  
You can achieve that by using the Lab on Demand 'VM Status' page in your reservation. 
In probably less than 30 seconds, the node will appear has _NotReady_:  
```bash
$ kubectl get node -l kubernetes.io/os=linux
NAME    STATUS                     ROLES           AGE    VERSION
rhel1   Ready,SchedulingDisabled   <none>          567d   v1.29.4
rhel2   NotReady                   <none>          567d   v1.29.4
rhel3   Ready                      control-plane   567d   v1.29.4
```
Exactly 5 minutes after the node status was updated, Kubernetes is going to try to restart the pods on a different node:  
```bash
$ kubectl get -n scenario28 po -o wide
NAME                               READY   STATUS              RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
busybox-iscsi-86bf85d6b7-j5w5c     1/1     Terminating         0          10m   192.168.28.83   rhel2   <none>           <none>
busybox-iscsi-86bf85d6b7-rjpn6     0/1     ContainerCreating   0          14s   <none>          rhel3   <none>           <none>
busybox-nfs-rwo-5994dd85c5-2mhx5   1/1     Terminating         0          10m   192.168.28.82   rhel2   <none>           <none>
busybox-nfs-rwo-5994dd85c5-fjckb   0/1     ContainerCreating   0          14s   <none>          rhel3   <none>           <none>
busybox-nfs-rwx-76488d5b4c-24cgn   1/1     Terminating         0          10m   192.168.28.71   rhel2   <none>           <none>
busybox-nfs-rwx-76488d5b4c-gfx82   1/1     Running             0          14s   192.168.25.70   rhel3   <none>           <none>
```
What do we see:  
- The 2 new pods mounting RWO PVC are stuck in _ContainerCreating_, simply because the pods on the failed nodes are stuck in _Terminating_ status. 
- The new pod mounting a RWX PVC is running, however there is still a failed connection on the failed node

You should also be able to read the connect of this last pod:  
```bash
$ kubectl exec -n scenario28 busybox-nfs-rwx-76488d5b4c-gfx82 -- more /data/test3.txt
test3!
```
But why 5 minutes (or 300 seconds)?  
This is managed by some **tolerations** you can find in the pods.  
By default, you will find in your applications the following:  
```bash
$ kubectl get pod -n scenario28 busybox-nfs-rwx-76488d5b4c-24cgn -o json | jq '.spec.tolerations'
[
  {
    "effect": "NoExecute",
    "key": "node.kubernetes.io/not-ready",
    "operator": "Exists",
    "tolerationSeconds": 300
  },
  {
    "effect": "NoExecute",
    "key": "node.kubernetes.io/unreachable",
    "operator": "Exists",
    "tolerationSeconds": 300
  }
]
```
These tolerations let the pod stay _running_ on a node for up to 300s after the node becomes _NotReady_ or _Unreachable_ (giving time for transient issues or graceful shutdown) before the pod is evicted and rescheduled elsewhere. If you want to demo this behavior, it may be wise to add those tolerations to the provided yaml manifests with lower values, so that you don't have to wait for the whole 300 seconds...  

Time to clean up!  
- first, restart the host from the lab page (the node will change to "Ready" state again and the _terminating_ pods will eventually then disappear). 
- delete the _scenario28_ namespace in order to remove all 3 apps all at once (*kubectl delete ns scenario28*).  

## B. Automated workload failover: requirements

Trident introduced the support for automated workloads failover (_AWF_) with force volume detach in 25.10. This is compatible with all Trident drivers except for ONTAP-NAS-FLEXGROUP. It really aims at offering business continuity for RWO Stateful applications, in the context of a node failure.   

AWF relies on the Node Health Check (_NHC_) operator to work. When a node fails, the NHC will trigger a new Trident CR called **Trident Node Remediation** (_TNR_) which will "force detach" all existing storage connections on the failed node.  

We will see in this chapter: 
- the operator framework installation. 
- the NHC operator installation. 
- the NHC operator configuration. 
- the Trident configuration

Let's start withe Operator SDK, which provides a toolkit to manage operators:  
```bash
export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')
export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.42.0
curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
chmod +x operator-sdk_${OS}_${ARCH} && mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk
```
We can now proceed with the Operator Lifecycle Manager (OLM) installation, which, well, manages the lifecycle of operators:  
```bash
operator-sdk olm install
```
Following that operation, you will have 2 new namespaces (as well as new CRD):  
- _olm_: the namespace where the OLM is installed. 
- _operators_: contains all the operators you may install. 

We can finally proceed with the installation of the NHC, which will be configured in the _operators_ namespace:  
```bash
$ kubectl create -f https://operatorhub.io/install/node-healthcheck-operator.yaml
subscription.operators.coreos.com/my-node-healthcheck-operator created
```
After a few seconds, you will get a few new pods, alongside other objects:  
```bash
$ kubectl get -n operators pod -l app.kubernetes.io/name=node-healthcheck-operator
NAME                                                        READY   STATUS    RESTARTS        AGE
node-healthcheck-controller-manager-597fb55f9f-6bdq5        2/2     Running   0               3m49s
node-healthcheck-controller-manager-597fb55f9f-82t9l        2/2     Running   0               3m49s
```
We can now configure the NHC to work with Trident, through a CR:  
```bash
$ cat << EOF | kubectl apply  -f -
apiVersion: remediation.medik8s.io/v1alpha1
kind: NodeHealthCheck
metadata:
  name: nhc-trident
  namespace: trident
spec:
  selector:
    matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: DoesNotExist
  remediationTemplate:
    apiVersion: trident.netapp.io/v1
    kind: TridentNodeRemediationTemplate
    namespace: trident
    name: trident-node-remediation-template
  minHealthy: 0 # Trigger force-detach upon one or more node failures
  unhealthyConditions:
    - type: Ready
      status: "False"
      duration: 0s
    - type: Ready
      status: Unknown
      duration: 0s
EOF
nodehealthcheck.remediation.medik8s.io/nhc-trident created
```

>> The above CR is configured to watch K8s worker nodes for node conditions Ready: _false_ and _Unknown_. Automated-Failover will be triggered upon a node going into _Ready: false_, or _Ready: Unknown_ state.

>> The unhealthyConditions in the CR uses a 0 second grace period. This causes automated-failover to trigger immediately upon K8s setting node condition Ready: false, which is set after K8s loses the heartbeat from a node. K8s has a default of 40sec wait after the last heartbeat before setting Ready: false. This grace-period can be customized in K8s deployment options.

The last step consists in enabling the _AWF_ feature in Trident. This is a global parameter set during the installation.  
If Trident was installed with Helm, you can just update the chart with a new flag:  
```bash
helm upgrade trident netapp-trident/trident-operator --version 100.2510.0 -n trident --set enableForceDetach=true --reuse-values
```
Within a minute, all the Trident pods (controller and daemonsets) will have restarted.  
If you now check the details of one of those pods, you will see a new parameter:  
```bash
$ kubectl get -n trident po -l app=controller.csi.trident.netapp.io -o yaml | grep force
      - --enable_force_detach=true
```

Done! The automated workflow failover feature is now active!

## C. Automated workload failover in action

We first need to cordon a worker node, especially the one carrying the Trident controller if not running on the control plane.  
Following the Trident update, the pod may have changed host:  
```bash
$ kubectl get -n trident po -l app=controller.csi.trident.netapp.io -o wide
NAME                                  READY   STATUS    RESTARTS   AGE     IP               NODE    NOMINATED NODE   READINESS GATES
trident-controller-6955d565dd-t7cck   6/6     Running   0          3m16s   192.168.28.113   rhel2   <none>           <none>

$ kubectl cordon rhel2
node/rhel2 cordoned
```

Let's recreate the _scenario28_ namespace, as well as the 3 applications:
```bash
kubectl create ns scenario28
kubectl create -f busybox_nfs_rwx.yaml -f busybox_nfs_rwo.yaml -f busybox_iscsi_rwo.yaml
```
The 3 pods should be running on the node _rhel1_:  
```bash
$ kubectl get -n scenario28 po -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP             NODE    NOMINATED NODE   READINESS GATES
busybox-iscsi-86bf85d6b7-xjd4c     1/1     Running   0          45s   192.168.26.6   rhel1   <none>           <none>
busybox-nfs-rwo-5994dd85c5-wtpdp   1/1     Running   0          45s   192.168.26.2   rhel1   <none>           <none>
busybox-nfs-rwx-76488d5b4c-pvvtw   1/1     Running   0          45s   192.168.26.5   rhel1   <none>           <none>
```
You can even create some content:  
```bash
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-iscsi -o name) -- sh -c 'echo "test1!" > /data/test1.txt'
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-nfs-rwo -o name) -- sh -c 'echo "test2!" > /data/test2.txt'
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-nfs-rwx -o name) -- sh -c 'echo "test3!" > /data/test3.txt'
```
Before moving on the failure simulation, let's _uncordon_ the second host, so that the pods can be rescheduled there:
```bash
$ kubectl uncordon rhel2
node/rhel2 cordoned
```
Time to see what happens when powering down a node (_rhel1_ in this case).  
It takes a few tens of seconds for the failure to be detected, at which point the _NHC_ immediatly & automatically creates a _TNR_ in the Trident namespace, which directly triggers the _AWF_ for all 3 pods. If you are quick, you will see the _TNR_ change status from _Remediating_ to _NodeRecoveryPending_:  
```bash
$ kubectl get tnr -n trident -w
NAME    STATE                 COMPLETION TIME   MESSAGE
rhel1   Remediating
rhel1   NodeRecoveryPending
```
You can see that the pods have all restarted on a different node:  
```bash
$ kubectl get -n scenario28 po -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
busybox-iscsi-86bf85d6b7-nnsf6     1/1     Running   0          18s   192.168.28.111   rhel2   <none>           <none>
busybox-nfs-rwo-5994dd85c5-gxt6j   1/1     Running   0          18s   192.168.28.107   rhel2   <none>           <none>
busybox-nfs-rwx-76488d5b4c-2hsvp   1/1     Running   0          18s   192.168.28.124   rhel2   <none>           <none>
```
Now, the TNR is waiting for the node to come back to life, or to be fully deleted.  
If you read the content of the TNR, you can also see the list of all the volumes that are involved in the remediation:  
```bash
kubectl -n trident get tnr -o json | jq '.items[].status.volumeAttachments'
{
  "csi-035832333b0741ff6f655c3e12935b484e3d532e04cf15a0406726d05cda3cce": "pvc-16ec69cf-0bc9-48c2-a9f4-1c204aa467bc",
  "csi-1c4a68016b7be6036018be13d5a8144f2e38579b7faf678a014c8626ad02f181": "pvc-1c741a00-d1ca-439f-aea7-542d8487fed7",
  "csi-ca5b1b78abe97525c43fdce7eecccb4017bc1bdad6c3927aa724e3da1e1a8d47": "pvc-799af565-db7e-44b2-9a64-13822ed40339"
}
```
You can safely restart the powered off node. A few minutes later, the TNR will be deleted.  

Of course, if you check the content of all 3 PVC, the file will be there:  
```bash
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-iscsi -o name) -- ls /data/
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-nfs-rwo -o name) -- ls /data/
kubectl exec -n scenario28 $(kubectl get pod -n scenario28 -l app=bbox-nfs-rwx -o name) -- ls /data/
```

Let's tidy up before moving on. Remove the namespace, as well as the NHC CR:  
```bash
kubectl delete ns scenrio28
kubectl delete nodehealthcheck nhc-trident -n trident
```
