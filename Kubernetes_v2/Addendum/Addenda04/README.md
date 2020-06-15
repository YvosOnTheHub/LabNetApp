#########################################################################################
# ADDENDA 4: How to upgrade the Kubernetes cluster
#########################################################################################

**GOAL:**  
Some interesting features require a more recent version than the one you find in this LabOnDemand:
- iSCSI PVC Resizing
- "On-Demand Snapshots" & "PVC from Snapshot"

Upgrades can only be done from one _minor_ version to the next. You need to perform two successive upgrades to go from 1.15 to 1.18.  
This addenda will give you the step by step commands to run, but keep in mind this is only for this lab... If you were to upgrade in a real environment, more care would need to be taken.

The following links were used :
- Upgrade from 1.15 to 1.16: https://v1-16.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  
- Upgrade from 1.16 to 1.17: https://v1-17.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  
- Upgrade from 1.17 to 1.18: https://v1-18.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  

Before upgrade to a specific version of Kubernetes, make sure you have upgraded Trident beforehand [(Scenario 1)](../../Scenarios/Scenario01)  


## A. Upgrade from 1.15.3 to 1.16.10

Let's look at the environment  
```
# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.15.3
rhel2   Ready    <none>   214d   v1.15.3
rhel3   Ready    master   214d   v1.15.3

# kubectl get pod -n trident -o wide
NAME                           READY   STATUS    RESTARTS   AGE    IP             NODE    NOMINATED NODE   READINESS GATES
trident-csi-6b778f79bb-tc9nk   3/3     Running   0          101m   10.36.0.1      rhel2   <none>           <none>
trident-csi-ndhzt              2/2     Running   2          101m   192.168.0.63   rhel3   <none>           <none>
trident-csi-vp4rb              2/2     Running   0          101m   192.168.0.62   rhel2   <none>           <none>
trident-csi-zw5h7              2/2     Running   2          101m   192.168.0.61   rhel1   <none>           <none>

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.3", GitCommit:"2d3c76f9091b6bec110a5e63777c332469e0cba2", GitTreeState:"clean", BuildDate:"2019-08-19T11:11:18Z", GoVersion:"go1.12.9", Compiler:"gc", Platform:"linux/amd64"}
```
Let's start with the master node (*rhel3*)
```
# yum install -y kubeadm-1.16.10-0 --disableexcludes=kubernetes

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.9", GitCommit:"a17149e1a189050796ced469dbd78d380f2ed5ef", GitTreeState:"clean", BuildDate:"2020-04-16T11:42:30Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
```
Next, we need to isolate this node, or avoid any new scheduling on the master node.  
Please note the following:  
- DaemonSets are built on everysingle node of the cluster. You need to specify a parameter to ignore them
- Some PODs have local storage, which needs to be handle. In some case (Trident's own replicaSet), you also need to use a specific parameter
```
# kubectl drain rhel3 --ignore-daemonsets
node/rhel3 cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-4hdjk, kube-system/weave-net-fgpl7, trident/trident-csi-ndhzt
evicting pod "coredns-5c98db65d4-x6j4l"
evicting pod "coredns-5c98db65d4-bnttk"
pod/coredns-5c98db65d4-bnttk evicted
pod/coredns-5c98db65d4-x6j4l evicted
node/rhel3 evicted

# kubectl get nodes
NAME    STATUS                     ROLES    AGE    VERSION
rhel1   Ready                      <none>   214d   v1.15.3
rhel2   Ready                      <none>   214d   v1.15.3
rhel3   Ready,SchedulingDisabled   master   214d   v1.15.3
```
We can now proceed with the upgrade
```
# kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     3 x v1.15.3   v1.16.10

Upgrade to the latest stable version:

COMPONENT            CURRENT   AVAILABLE
API Server           v1.15.3   v1.16.10
Controller Manager   v1.15.3   v1.16.10
Scheduler            v1.15.3   v1.16.10
Kube Proxy           v1.15.3   v1.16.01
CoreDNS              1.3.1     1.6.2
Etcd                 3.3.10    3.3.15-0

You can now apply the upgrade by executing the following command:

        kubeadm upgrade apply v1.16.10
_____________________________________________________________________

# kubeadm upgrade apply v1.16.10
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade/version] You have chosen to change the cluster version to "v1.16.10"
[upgrade/versions] Cluster version: v1.15.3
[upgrade/versions] kubeadm version: v1.16.10
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.16.10". Enjoy!
[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```
We can now enable _scheduling_ again on the master.
```
# kubectl uncordon rhel3
node/rhel3 uncordoned
```
Last, we can now upgrade _kubectl_ & _kubelet_:
```
# yum install -y kubelet-1.16.10-0 kubectl-1.16.10-0 --disableexcludes=kubernetes

# systemctl restart kubelet

# kubectl version
Client Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.10", GitCommit:"f3add640dbcd4f3c33a7749f38baaac0b3fe810d", GitTreeState:"clean", BuildDate:"2020-05-20T14:00:52Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.10", GitCommit:"f3add640dbcd4f3c33a7749f38baaac0b3fe810d", GitTreeState:"clean", BuildDate:"2020-05-20T13:51:56Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
```
And after a few seconds, you can see the version:
```
# kubectl get node
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.15.3
rhel2   Ready    <none>   214d   v1.15.3
rhel3   Ready    master   214d   v1.16.10
```
We can now process with the worker nodes, one by one.  
I will first show the procedure for the first node _rhel1_, which is the node that does not host Trident's replicaSet.  
First, install the new version of Kubeadm:
```
# yum install -y kubeadm-1.16.10-0 --disableexcludes=kubernetes
```
Then, from the *master* node, unschedule the creation of new PODs on the worker node
```
# kubectl drain rhel1 --ignore-daemonsets
node/rhel1 cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-tp986, kube-system/weave-net-xh8wg, trident/trident-csi-zw5h7
evicting pod "coredns-5644d7b6d9-5s5jg"
pod/coredns-5644d7b6d9-5s5jg evicted
node/rhel1 evicted

# kubectl get node
NAME    STATUS                     ROLES    AGE    VERSION
rhel1   Ready,SchedulingDisabled   <none>   214d   v1.15.3
rhel2   Ready                      <none>   214d   v1.15.3
rhel3   Ready                      master   214d   v1.16.10
```
Time to upgrade the worker node
```
# kubeadm upgrade node
[upgrade] Reading configuration from the cluster...
[upgrade] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[upgrade] Skipping phase. Not a control plane node[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.16" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade] The configuration for this node was successfully updated!
[upgrade] Now you should go ahead and upgrade the kubelet package using your package manager.

# yum install -y kubelet-1.16.10-0 kubectl-1.16.10-0 --disableexcludes=kubernetes

# systemctl restart kubelet
```
You can now enable the scheduling on this worker node, from the master node
```
# kubectl uncordon rhel1
node/rhel1 uncordoned
```
Upgrading the other node _rhel2_ requires an extra procedure.  
```
# kubectl drain rhel2 --ignore-daemonsets
node/rhel2 cordoned
error: unable to drain node "rhel2", aborting command...

There are pending nodes to be drained:
 rhel2
error: cannot delete Pods with local storage (use --delete-local-data to override): trident/trident-csi-6b778f79bb-fr4f2
```
Apparently Trident's replicaSet uses some local storage. This can be verified with the following:
```
# kubectl describe pod -n trident trident-csi-6b778f79bb-fr4f2
Name:         trident-csi-6b778f79bb-fr4f2
Namespace:    trident
Priority:     0
Node:         rhel2/192.168.0.62
...
Volumes:
  socket-dir:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
  certs:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  trident-csi
    Optional:    false
  trident-csi-token-gd8vt:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  trident-csi-token-gd8vt
    Optional:    false
...
```
The problematic volume is _socket_dir_. The warning can be ignored. But keep in mind that for other workloads, you may need extra care.
```
# kubectl drain rhel2 --ignore-daemonsets --delete-local-data
node/rhel2 already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-2m89p, kube-system/weave-net-n2v6b, trident/trident-csi-vp4rb
evicting pod "trident-csi-6b778f79bb-fr4f2"
pod/trident-csi-6b778f79bb-fr4f2 evicted
node/rhel2 evicted

# kubectl get pod -n trident -o wide
NAME                           READY   STATUS    RESTARTS   AGE    IP             NODE    NOMINATED NODE   READINESS GATES
trident-csi-6b778f79bb-pqcsp   3/3     Running   0          109s   10.36.0.1      rhel1   <none>           <none>
trident-csi-ndhzt              2/2     Running   2          116m   192.168.0.63   rhel3   <none>           <none>
trident-csi-vp4rb              2/2     Running   0          116m   192.168.0.62   rhel2   <none>           <none>
trident-csi-zw5h7              2/2     Running   2          116m   192.168.0.61   rhel1   <none>           <none>
```
Trident's ReplicaSet has been moved to another node.  
You can now proceed with the upgrade following the same steps as the other worker node.
You will end up with the following:
```
# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.16.10
rhel2   Ready    <none>   214d   v1.16.10
rhel3   Ready    master   214d   v1.16.10
```
Tadaaa !  

When you upgrade Kubernetes, Trident does not automatically upgrade its configuration.  
Kubernetes 1.16 promoted PVC Expansion to Beta status, which implies a new CSI Sidecar. In order to activate this sidecar, Trident needs to be resintalled.  
Can you spot the new sidecar in the following output?
```
# K8S 1.16 & BEFORE TRIDENT 20.01.1 REINSTALL
# kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-6b778f79bb-4sj4h:  netapp/trident:20.01.1, quay.io/k8scsi/csi-provisioner:v1.5.0, quay.io/k8scsi/csi-attacher:v2.1.0,
trident-csi-brd4h:     netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-bwjn7:     netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-lfdjl:     netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,

# tridentctl -n trident uninstall --silent
# tridentctl -n trident install --silent

#K8S 1.16 & AFTER TRIDENT 20.01.1 REINSTALL
# kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-bc2qt:     netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-d8667b7fd-df9lr:   netapp/trident:20.01.1, quay.io/k8scsi/csi-provisioner:v1.5.0, quay.io/k8scsi/csi-attacher:v2.1.0, quay.io/k8scsi/csi-resizer:v0.4.0,
trident-csi-jvph8:     netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-zmfz4:     netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
```


## B. Upgrade from 1.16.10 to 1.17.6

The procedure to go from 1.16.10 to 1.17.6 is pretty similar to the previous one.  
```
# yum install -y kubeadm-1.17.6-0 --disableexcludes=kubernetes

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.6", GitCommit:"d32e40e20d167e103faf894261614c5b45c44198", GitTreeState:"clean", BuildDate:"2020-05-20T13:14:10Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}

# kubectl drain rhel3 --ignore-daemonsets
node/rhel3 cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-8hvmt, kube-system/weave-net-fgpl7, trident/trident-csi-ndhzt
evicting pod "coredns-5644d7b6d9-jp9tn"
pod/coredns-5644d7b6d9-jp9tn evicted
node/rhel3 evicted

# kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT        AVAILABLE
Kubelet     3 x v1.16.10   v1.17.6

Upgrade to the latest stable version:

COMPONENT            CURRENT    AVAILABLE
API Server           v1.16.10   v1.17.6
Controller Manager   v1.16.10   v1.17.6
Scheduler            v1.16.10   v1.17.6
Kube Proxy           v1.16.10   v1.17.6
CoreDNS              1.6.2      1.6.5
Etcd                 3.3.15     3.4.3-0

You can now apply the upgrade by executing the following command:
        kubeadm upgrade apply v1.17.6

# kubeadm upgrade apply v1.17.6
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade/version] You have chosen to change the cluster version to "v1.17.6"
[upgrade/versions] Cluster version: v1.16.10
[upgrade/versions] kubeadm version: v1.17.6
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.17.6". Enjoy!

# kubectl uncordon rhel3
node/rhel3 uncordoned

# yum install -y kubelet-1.17.6-0 kubectl-1.17.6-0 --disableexcludes=kubernetes

# systemctl restart kubelet

# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.16.10
rhel2   Ready    <none>   214d   v1.16.10
rhel3   Ready    master   214d   v1.17.6
```
Let's process with the worker node _rhel1_. Again, you need to start by _draining_ it from the master.
```
# kubectl drain rhel1 --ignore-daemonsets
node/rhel1 cordoned
evicting pod "coredns-6955765f44-2rhkh"
pod/coredns-6955765f44-2rhkh evicted
node/rhel1 evicted

# kubectl get pod -n trident -o wide
NAME                           READY   STATUS    RESTARTS   AGE    IP             NODE    NOMINATED NODE   READINESS GATES
trident-csi-6b778f79bb-pqcsp   3/3     Running   0          18m    10.36.0.1      rhel1   <none>           <none>
trident-csi-ndhzt              2/2     Running   2          133m   192.168.0.63   rhel3   <none>           <none>
trident-csi-vp4rb              2/2     Running   2          133m   192.168.0.62   rhel2   <none>           <none>
trident-csi-zw5h7              2/2     Running   2          133m   192.168.0.61   rhel1   <none>           <none>

```
If you remember, Trident's ReplicaSet is on this host. This upgrade procedure does not complain about its volume anymore.  
Back to _rhel1_:
```
# yum install -y kubeadm-1.17.6-0 --disableexcludes=kubernetes

# kubeadm upgrade node

# yum install -y kubelet-1.17.6-0 kubectl-1.17.6-0 --disableexcludes=kubernetes

# systemctl restart kubelet
```
Back to the master:  
```
# kubectl uncordon rhel1
node/rhel1 uncordoned

# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.17.6
rhel2   Ready    <none>   214d   v1.16.10
rhel3   Ready    master   214d   v1.17.6
```
You now can repeat this procedure on the second worker node, until you get to:
```
# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.17.6
rhel2   Ready    <none>   214d   v1.17.6
rhel3   Ready    master   214d   v1.17.6
```
Tadaaa again !

Again, you have to upgrade Trident.  
Kubernetes 1.17 promoted PVC Snapshot&Restore to Beta status, which implies a new CSI Sidecar.  
Can you spot the new sidecar in the following output?
```
# K8S 1.17 & BEFORE TRIDENT 20.01.1 REINSTALL
# kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-bc2qt:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-d8667b7fd-df9lr:    netapp/trident:20.01.1, quay.io/k8scsi/csi-provisioner:v1.5.0, quay.io/k8scsi/csi-attacher:v2.1.0, quay.io/k8scsi/csi-resizer:v0.4.0,
trident-csi-jvph8:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-zmfz4:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,

# tridentctl -n trident uninstall --silent
# tridentctl -n trident install --silent

# K8S 1.17 & AFTER TRIDENT 20.01.1 REINSTALL
# kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-4gj4j:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-5cd46cff6-5h9h8:    netapp/trident:20.01.1, quay.io/k8scsi/csi-provisioner:v1.5.0, quay.io/k8scsi/csi-attacher:v2.1.0, quay.io/k8scsi/csi-resizer:v0.4.0, quay.io/k8scsi/csi-snapshotter:v2.0.1,
trident-csi-5vhrv:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-tttn4:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
```


## C. Upgrade from 1.17.5 to 1.18.2

The procedure to go from 1.17.5 to 1.18.2 is pretty similar to the previous one.  
```
# yum install -y kubeadm-1.18.2-0 --disableexcludes=kubernetes

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.2", GitCommit:"52c56ce7a8272c798dbc29846288d7cd9fbae032", GitTreeState:"clean", BuildDate:"2020-04-16T11:54:15Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}

# kubectl drain rhel3 --ignore-daemonsets
node/rhel3 cordoned
node/rhel3 drained

# kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     4 x v1.17.5   v1.18.2

Upgrade to the latest stable version:
COMPONENT            CURRENT   AVAILABLE
API Server           v1.17.5   v1.18.2
Controller Manager   v1.17.5   v1.18.2
Scheduler            v1.17.5   v1.18.2
Kube Proxy           v1.17.5   v1.18.2
CoreDNS              1.6.5     1.6.7
Etcd                 3.4.3     3.4.3-0

You can now apply the upgrade by executing the following command:
        kubeadm upgrade apply v1.18.2


# kubeadm upgrade apply v1.18.2
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.18.2"
[upgrade/versions] Cluster version: v1.17.5
[upgrade/versions] kubeadm version: v1.18.2
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.18.2". Enjoy!

# kubectl uncordon rhel3
node/rhel3 uncordoned

# yum install -y kubelet-1.18.2-0 kubectl-1.18.2-0 --disableexcludes=kubernetes

# systemctl restart kubelet

# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.17.5
rhel2   Ready    <none>   214d   v1.17.5
rhel3   Ready    master   214d   v1.18.2
```
Let's process with the worker node _rhel1_. Again, you need to start by _draining_ it from the master.
In some cases, Kubernetes may complain that some PODs have local data attached. _Draining_ such node could have some impact with your applications (but not Trident).  
If this happens, the option _--delete-local-data_ would need to be used in the _drain_ command.
```
# kubectl drain rhel1 --ignore-daemonsets
node/rhel1 cordoned
evicting pod "coredns-6955765f44-2rhkh"
pod/coredns-6955765f44-2rhkh evicted
node/rhel1 evicted
```
Back to _rhel1_:
```
# yum install -y kubeadm-1.18.2-0 --disableexcludes=kubernetes

# kubeadm upgrade node

# yum install -y kubelet-1.18.2-0 kubectl-1.18.2-0 --disableexcludes=kubernetes

# systemctl restart kubelet
```
Back to the master:  
```
# kubectl uncordon rhel1
node/rhel1 uncordoned

# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.18.2
rhel2   Ready    <none>   214d   v1.17.5
rhel3   Ready    master   214d   v1.18.2
```
You now can repeat this procedure on the second worker node, until you get to:
```
# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.18.2
rhel2   Ready    <none>   214d   v1.18.2
rhel3   Ready    master   214d   v1.18.2
```
Tadaaa again !
```



## D. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?