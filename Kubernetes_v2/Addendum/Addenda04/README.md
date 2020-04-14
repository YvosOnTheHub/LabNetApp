#########################################################################################
# ADDENDA 4: How to upgrade the Kubernetes cluster
#########################################################################################

GOAL:  
Some interesting features require a more recent version than the one you find in this LabOnDemand:
- iSCSI PVC Resizing
- "On-Demand Snapshots" & "PVC from Snapshot"

Upgrades can only be done from one _minor_ version to the next. You need to perform two successive upgrades to go from 1.15 to 1.17.  
This addenda will give you the step by step commands to run, but keep in mind this is only for this lab... If you were to upgrade in a real environment, more care would need to be taken.

The following links were used :
- Upgrade from 1.15 to 1.16: https://v1-16.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  
- Upgrade from 1.16 to 1.17: https://v1-17.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  

Before upgrade Kubernetes, make sure you have upgraded Trident beforehand, with at least v20.01.1 [(Scenario 1)](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Scenarios/Scenario01)  


## A. Upgrade from 1.15.3 to 1.16.8

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
# yum install -y kubeadm-1.16.8-0 --disableexcludes=kubernetes

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.8", GitCommit:"ec6eb119b81be488b030e849b9e64fda4caaf33c", GitTreeState:"clean", BuildDate:"2020-03-12T20:57:57Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
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
Kubelet     3 x v1.15.3   v1.16.8

Upgrade to the latest stable version:

COMPONENT            CURRENT   AVAILABLE
API Server           v1.15.3   v1.16.8
Controller Manager   v1.15.3   v1.16.8
Scheduler            v1.15.3   v1.16.8
Kube Proxy           v1.15.3   v1.16.8
CoreDNS              1.3.1     1.6.2
Etcd                 3.3.10    3.3.15-0

You can now apply the upgrade by executing the following command:

        kubeadm upgrade apply v1.16.8
_____________________________________________________________________

# kubeadm upgrade apply v1.16.8
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade/version] You have chosen to change the cluster version to "v1.16.8"
[upgrade/versions] Cluster version: v1.15.3
[upgrade/versions] kubeadm version: v1.16.8
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.16.8". Enjoy!
[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```
We can now enable _scheduling_ again on the master.
```
# kubectl uncordon rhel3
node/rhel3 uncordoned
```
Last, we can now upgrade _kubectl_ & _kubelet_:
```
# yum install -y kubelet-1.16.8-0 kubectl-1.16.8-0 --disableexcludes=kubernetes

# systemctl restart kubelet

# kubectl version
Client Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.8", GitCommit:"ec6eb119b81be488b030e849b9e64fda4caaf33c", GitTreeState:"clean", BuildDate:"2020-03-12T21:00:06Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.8", GitCommit:"ec6eb119b81be488b030e849b9e64fda4caaf33c", GitTreeState:"clean", BuildDate:"2020-03-12T20:52:22Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
```
And after a few seconds, you can see the version:
```
# kubectl get node
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.15.3
rhel2   Ready    <none>   214d   v1.15.3
rhel3   Ready    master   214d   v1.16.8
```
We can now process with the worker nodes, one by one.  
I will first show the procedure for the first node _rhel1_, which is the node that does not host Trident's replicaSet.  
First, install the new version of Kubeadm:
```
# yum install -y kubeadm-1.16.8-0 --disableexcludes=kubernetes
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
rhel3   Ready                      master   214d   v1.16.8
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

# yum install -y kubelet-1.16.8-0 kubectl-1.16.8-0 --disableexcludes=kubernetes

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
rhel1   Ready    <none>   214d   v1.16.8
rhel2   Ready    <none>   214d   v1.16.8
rhel3   Ready    master   214d   v1.16.8
```
Tadaaa !  

For some reason that remains to be explained, not all features will work (ex: PVC Resize).  Trident needs to be reinstalled in order to re-enable them.  
This is only true when upgrading Kubernetes from 1.15 to 1.16.
```
# tridentctl -n trident uninstall
# tridentctl -n trident install
```


## B. Upgrade from 1.16.8 to 1.17.4

The procedure to go from 1.16.8 to 1.17.4 is pretty similar to the previous one.  
```
# yum install -y kubeadm-1.17.4-0 --disableexcludes=kubernetes

# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.4", GitCommit:"8d8aa39598534325ad77120c120a22b3a990b5ea", GitTreeState:"clean", BuildDate:"2020-03-12T21:01:11Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}

# kubectl drain rhel3 --ignore-daemonsets
node/rhel3 cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-8hvmt, kube-system/weave-net-fgpl7, trident/trident-csi-ndhzt
evicting pod "coredns-5644d7b6d9-jp9tn"
pod/coredns-5644d7b6d9-jp9tn evicted
node/rhel3 evicted

# kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     3 x v1.16.8   v1.17.4

Upgrade to the latest stable version:

COMPONENT            CURRENT   AVAILABLE
API Server           v1.16.8   v1.17.4
Controller Manager   v1.16.8   v1.17.4
Scheduler            v1.16.8   v1.17.4
Kube Proxy           v1.16.8   v1.17.4
CoreDNS              1.6.2     1.6.5
Etcd                 3.3.15    3.4.3-0

You can now apply the upgrade by executing the following command:
        kubeadm upgrade apply v1.17.4

# kubeadm upgrade apply v1.17.4
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade/version] You have chosen to change the cluster version to "v1.17.4"
[upgrade/versions] Cluster version: v1.16.8
[upgrade/versions] kubeadm version: v1.17.4
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.17.4". Enjoy!

# kubectl uncordon rhel3
node/rhel3 uncordoned

# yum install -y kubelet-1.17.4-0 kubectl-1.17.4-0 --disableexcludes=kubernetes

# systemctl restart kubelet

# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.16.8
rhel2   Ready    <none>   214d   v1.16.8
rhel3   Ready    master   214d   v1.17.4
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
# yum install -y kubeadm-1.17.4-0 --disableexcludes=kubernetes

# kubeadm upgrade node

# yum install -y kubelet-1.17.4-0 kubectl-1.17.4-0 --disableexcludes=kubernetes

# systemctl restart kubelet
```
Back to the master:  
```
# kubectl uncordon rhel1
node/rhel1 uncordoned

# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.17.4
rhel2   Ready    <none>   214d   v1.16.8
rhel3   Ready    master   214d   v1.17.4
```
You now can repeat this procedure on the second worker node, until you get to:
```
# kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   214d   v1.17.4
rhel2   Ready    <none>   214d   v1.17.4
rhel3   Ready    master   214d   v1.17.4
```
Tadaaa again !