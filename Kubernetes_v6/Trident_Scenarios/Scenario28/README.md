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
- RWX: by definition, multiple pods can mount a volume. Even if an existing connectivity is not cleaned up, a new pod will ne able to mount a PVC

Let's see that in action.
We will create 3 applications in a given namespace:  
- iSCSI PVC in RWO  
- NFS PVC in RWO  
- NFS PVC in RWX

In order to make sure the 3 apps start on the same node, let's _cordon_ one of them:  
```bash
$ kubectl cordon rhel1
node/rhel1 cordoned

$ kubectl get node -l kubernetes.io/os=linux
NAME    STATUS                     ROLES           AGE    VERSION
rhel1   Ready,SchedulingDisabled   <none>          567d   v1.29.4
rhel2   Ready                      <none>          567d   v1.29.4
rhel3   Ready                      control-plane   567d   v1.29.4
```
With scheduled disabled on the _rhel1_, the applications should start on _rhel2_:  
```bash
$ kubectl create ns sc28busybox
namespace/sc28busybox created

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
$ kubectl gget -n sc28busybox pvc
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
mydata-iscsi     Bound    pvc-28883b4e-4b93-4bd5-a2d2-a354aaf0074c   1Gi        RWO            storage-class-iscsi   <unset>                 67s
mydata-nfs-rwo   Bound    pvc-594bc3a8-64a6-4d09-9e69-0a7e450fd645   1Gi        RWO            storage-class-nfs     <unset>                 67s
mydata-nfs-rwx   Bound    pvc-593ca681-8086-4d7c-adff-b96021206e5b   1Gi        RWX            storage-class-nfs     <unset>                 67s

$ kubectl get -n sc28busybox po -o wide
NAME                               READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
busybox-iscsi-86bf85d6b7-6cvhx     1/1     Running   0          56s   192.168.28.74    rhel2   <none>           <none>
busybox-nfs-rwo-5994dd85c5-ldms9   1/1     Running   0          56s   192.168.28.121   rhel2   <none>           <none>
busybox-nfs-rwx-76488d5b4c-xmtt2   1/1     Running   0          56s   192.168.28.66    rhel2   <none>           <none>
```


hel3 ~]#  kubectl get node -l kubernetes.io/os=linux
NAME    STATUS                     ROLES           AGE    VERSION
rhel1   Ready,SchedulingDisabled   <none>          567d   v1.29.4
rhel2   NotReady                   <none>          567d   v1.29.4
rhel3   Ready                      control-plane   567d   v1.29.4


[root@rhel3 ~]#  kubectl get -n sc28busybox po -o wide
NAME                               READY   STATUS              RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
busybox-iscsi-86bf85d6b7-6cvhx     1/1     Terminating         0          16m   192.168.28.74    rhel2   <none>           <none>
busybox-iscsi-86bf85d6b7-ss2wj     0/1     ContainerCreating   0          33s   <none>           rhel3   <none>           <none>
busybox-nfs-rwo-5994dd85c5-ldms9   1/1     Terminating         0          16m   192.168.28.121   rhel2   <none>           <none>
busybox-nfs-rwo-5994dd85c5-vfdb4   0/1     ContainerCreating   0          33s   <none>           rhel3   <none>           <none>
busybox-nfs-rwx-76488d5b4c-xmtt2   1/1     Terminating         0          16m   192.168.28.66    rhel2   <none>           <none>
busybox-nfs-rwx-76488d5b4c-zzttw   1/1     Running             0          33s   192.168.25.114   rhel3   <none>           <none>



 grep -nE 'GracefulNodeShutdown|shutdownGracePeriod' /var/lib/kubelet/config.yaml || true
40:shutdownGracePeriod: 0s
41:shutdownGracePeriodCriticalPods: 0s

If shutdownGracePeriod* are set to "0s" (or absent and feature disabled) the kubelet will not perform graceful node shutdown.

Note that by default, both configuration options described below, shutdownGracePeriod and shutdownGracePeriodCriticalPods, are set to zero, thus not activating the graceful node shutdown functionality. To activate the feature, both options should be configured appropriately and set to non-zero values.

Reasoning: shutdownGracePeriod must be long enough to let your pods stop cleanly. If your pods use terminationGracePeriodSeconds=120s, set shutdownGracePeriod to >= 2m (e.g. 3m–5m) to give a buffer.





The graceful node shutdown feature is configured with two KubeletConfiguration options:

shutdownGracePeriod:

Specifies the total duration that the node should delay the shutdown by. This is the total grace period for pod termination for both regular and critical pods.

shutdownGracePeriodCriticalPods:

Specifies the duration used to terminate critical pods during a node shutdown. This value should be less than shutdownGracePeriod.





Enable AF


Install operator SDK
export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')
export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.42.0
curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}
chmod +x operator-sdk_${OS}_${ARCH} && sudo mv operator-sdk_${OS}_${ARCH} /usr/local/bin/operator-sdk

Install Operator Lifecycle Manager (OLM)
operator-sdk olm install

Install Node Health check Operator: 
kubectl create -f https://operatorhub.io/install/node-healthcheck-operator.yaml

[root@rhel3 LabNetApp]# kg -n operators po
NAME                                                       READY   STATUS    RESTARTS      AGE
node-healthcheck-controller-manager-5cd4c7db56-4pn9m       2/2     Running   0             57s
node-healthcheck-controller-manager-5cd4c7db56-rfmmt       2/2     Running   0             57s
self-node-remediation-controller-manager-5b85b7d88-2chbd   2/2     Running   1 (34s ago)   54s


cat << EOF | kubectl apply  -f -
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


helm upgrade trident netapp-trident/trident-operator --version 100.2510.0 -n trident --set enableForceDetach=true --reuse-values

[root@rhel3 LabNetApp]# kg -n trident po -l app=controller.csi.trident.netapp.io -o yaml | grep force
      - --enable_force_detach=true

[root@rhel3 LabNetApp]# kg tnrt -A
NAMESPACE   NAME                                AGE
trident     trident-node-remediation-template   89s



[root@rhel3 ~]# kc -f bbox.yaml
namespace/sc28busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

[root@rhel3 ~]# kg -n sc28busybox po -o wide
NAME                       READY   STATUS    RESTARTS   AGE     IP              NODE    NOMINATED NODE   READINESS GATES
busybox-64456cb48b-6dsbx   1/1     Running   0          4m13s   192.168.26.17   rhel1   <none>           <none>
[root@rhel3 ~]# kg -n sc28busybox pvc
NAME     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        VOLUMEATTRIBUTESCLASS   AGE
mydata   Bound    pvc-783de0f3-517f-4974-8e6f-ed9521282e83   1Gi        RWX            storage-class-nfs   <unset>                 4m16s


[root@rhel3 ~]# kg node
NAME    STATUS     ROLES           AGE    VERSION
rhel1   NotReady   <none>          566d   v1.29.4
rhel2   Ready      <none>          566d   v1.29.4
rhel3   Ready      control-plane   566d   v1.29.4

cat << EOF | kubectl apply  -f -
apiVersion: trident.netapp.io/v1
kind: TridentNodeRemediation
metadata:
  name: rhel1
  namespace: trident
spec: {}
EOF
tridentnoderemediation.trident.netapp.io/rhel1 created

[root@rhel3 ~]# kg tnr -A
NAMESPACE   NAME    STATE                 COMPLETION TIME   MESSAGE
trident     rhel1   NodeRecoveryPending

kg -n sc28busybox po -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
busybox-64456cb48b-9pnx7   1/1     Running   0          3m    192.168.28.79   rhel2   <none>           <none>

[root@rhel3 ~]# kg tnr -A -w
NAMESPACE   NAME    STATE                 COMPLETION TIME   MESSAGE
trident     rhel1   NodeRecoveryPending
trident     rhel1   NodeRecoveryPending
trident     rhel1   Succeeded
trident     rhel1   Succeeded

