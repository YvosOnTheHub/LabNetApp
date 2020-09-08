#########################################################################################
# ADDENDA 4: Upgrade to 1.17
#########################################################################################

**GOAL:**  
You are currently running Kubernetes 1.16 & would like to upgrade to 1.17.  

The procedure to go from 1.16.15 to 1.17.8 is pretty similar to the one used previously.  

```bash
$ yum install -y kubeadm-1.17.11-0 --disableexcludes=kubernetes

$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.11", GitCommit:"ea5f00d93211b7c80247bf607cfa422ad6fb5347", GitTreeState:"clean", BuildDate:"2020-08-13T15:17:52Z", GoVersion:"go1.13.15", Compiler:"gc", Platform:"linux/amd64"}

$ kubectl drain rhel3 --ignore-daemonsets
node/rhel3 cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-8hvmt, kube-system/weave-net-fgpl7, trident/trident-csi-ndhzt
evicting pod "coredns-5644d7b6d9-jp9tn"
pod/coredns-5644d7b6d9-jp9tn evicted
node/rhel3 evicted

$ kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT        AVAILABLE
Kubelet     3 x v1.16.15   v1.17.11

Upgrade to the latest stable version:

COMPONENT            CURRENT    AVAILABLE
API Server           v1.16.15   v1.17.11
Controller Manager   v1.16.15   v1.17.11
Scheduler            v1.16.15   v1.17.11
Kube Proxy           v1.16.15   v1.17.11
CoreDNS              1.6.2      1.6.5
Etcd                 3.3.15     3.4.3-0

You can now apply the upgrade by executing the following command:
        kubeadm upgrade apply v1.17.11

$ kubeadm upgrade apply v1.17.11 -y
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Making sure the cluster is healthy:
[upgrade/version] You have chosen to change the cluster version to "v1.17.11"
[upgrade/versions] Cluster version: v1.16.15
[upgrade/versions] kubeadm version: v1.17.11
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.17.11". Enjoy!

$ kubectl uncordon rhel3
node/rhel3 uncordoned

$ yum install -y kubelet-1.17.11-0 kubectl-1.17.11-0 --disableexcludes=kubernetes

$ systemctl restart kubelet
$ systemctl daemon-reload

$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.16.15
rhel2   Ready    <none>   294d   v1.16.15
rhel3   Ready    master   294d   v1.17.11
```

Let's process with the worker node _rhel1_. Again, you need to start by _draining_ it from the master.

```bash
$ kubectl drain rhel1 --ignore-daemonsets
node/rhel1 cordoned
evicting pod "coredns-6955765f44-2rhkh"
pod/coredns-6955765f44-2rhkh evicted
node/rhel1 evicted

$ kubectl get pod -n trident -o wide
NAME                           READY   STATUS    RESTARTS   AGE    IP             NODE    NOMINATED NODE   READINESS GATES
trident-csi-6b778f79bb-pqcsp   3/3     Running   0          18m    10.36.0.1      rhel1   <none>           <none>
trident-csi-ndhzt              2/2     Running   2          133m   192.168.0.63   rhel3   <none>           <none>
trident-csi-vp4rb              2/2     Running   2          133m   192.168.0.62   rhel2   <none>           <none>
trident-csi-zw5h7              2/2     Running   2          133m   192.168.0.61   rhel1   <none>           <none>
```

If you remember, Trident's ReplicaSet is on this host. This upgrade procedure does not complain about its volume anymore.  
Back to _rhel1_:

```bash
yum install -y kubeadm-1.17.11-0 --disableexcludes=kubernetes

kubeadm upgrade node

yum install -y kubelet-1.17.11-0 kubectl-1.17.11-0 --disableexcludes=kubernetes

systemctl restart kubelet
systemctl daemon-reload
```

Back to the master:  

```bash
$ kubectl uncordon rhel1
node/rhel1 uncordoned

$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.17.11
rhel2   Ready    <none>   294d   v1.16.15
rhel3   Ready    master   294d   v1.17.11
```

You now can repeat this procedure on the second worker node, until you get to:

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.17.11
rhel2   Ready    <none>   294d   v1.17.11
rhel3   Ready    master   294d   v1.17.11
```

Tadaaa again !

Again, you have to upgrade Trident.  
Kubernetes 1.17 promoted PVC Snapshot&Restore to Beta status, which implies a new CSI Sidecar.  
Can you spot the new sidecar in the following output?

```bash
# K8S 1.17 & BEFORE TRIDENT 20.01.1 REINSTALL
$ kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-bc2qt:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-d8667b7fd-df9lr:    netapp/trident:20.01.1, quay.io/k8scsi/csi-provisioner:v1.5.0, quay.io/k8scsi/csi-attacher:v2.1.0, quay.io/k8scsi/csi-resizer:v0.4.0,
trident-csi-jvph8:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-zmfz4:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,

$ tridentctl -n trident uninstall --silent
$ tridentctl -n trident install --silent

# K8S 1.17 & AFTER TRIDENT 20.01.1 REINSTALL
$ kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-4gj4j:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-5cd46cff6-5h9h8:    netapp/trident:20.01.1, quay.io/k8scsi/csi-provisioner:v1.5.0, quay.io/k8scsi/csi-attacher:v2.1.0, quay.io/k8scsi/csi-resizer:v0.4.0, quay.io/k8scsi/csi-snapshotter:v2.0.1,
trident-csi-5vhrv:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
trident-csi-tttn4:      netapp/trident:20.01.1, quay.io/k8scsi/csi-node-driver-registrar:v1.2.0,
```

## What's next

You can [upgrade to 1.18](../upgrade_to_1.18)  
Or go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?