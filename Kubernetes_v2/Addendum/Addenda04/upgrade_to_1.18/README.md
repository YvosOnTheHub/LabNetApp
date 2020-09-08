#########################################################################################
# ADDENDA 4: Upgrade to 1.18
#########################################################################################

**GOAL:**  
You are currently running Kubernetes 1.17 & would like to upgrade to 1.18.  

The procedure to go from 1.17.11 to 1.18.5 is pretty similar to the previous one.  

```bash
$ yum install -y kubeadm-1.18.5-0 --disableexcludes=kubernetes

$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.5", GitCommit:"e6503f8d8f769ace2f338794c914a96fc335df0f", GitTreeState:"clean", BuildDate:"2020-06-26T03:45:16Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}

$ kubectl drain rhel3 --ignore-daemonsets
node/rhel3 cordoned
node/rhel3 drained

$ kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
Kubelet     3 x v1.17.11   v1.18.5

Upgrade to the latest stable version:
COMPONENT            CURRENT    AVAILABLE
API Server           v1.17.11   v1.18.5
Controller Manager   v1.17.11   v1.18.5
Scheduler            v1.17.11   v1.18.5
Kube Proxy           v1.17.11   v1.18.5
CoreDNS              1.6.5      1.6.7
Etcd                 3.4.3      3.4.3-0

You can now apply the upgrade by executing the following command:
        kubeadm upgrade apply v1.18.5


$ kubeadm upgrade apply v1.18.5 -y
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.18.5"
[upgrade/versions] Cluster version: v1.17.11
[upgrade/versions] kubeadm version: v1.18.5
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.18.5". Enjoy!

$ kubectl uncordon rhel3
node/rhel3 uncordoned

$ yum install -y kubelet-1.18.5-0 kubectl-1.18.5-0 --disableexcludes=kubernetes

$ systemctl restart kubelet
$ systemctl daemon-reload

$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.17.11
rhel2   Ready    <none>   294d   v1.17.11
rhel3   Ready    master   294d   v1.18.5
```

Let's process with the worker node _rhel1_. Again, you need to start by _draining_ it from the master.
In some cases, Kubernetes may complain that some PODs have local data attached. _Draining_ such node could have some impact with your applications (but not Trident).  
If this happens, the option _--delete-local-data_ would need to be used in the _drain_ command.

```bash
$ kubectl drain rhel1 --ignore-daemonsets
node/rhel1 cordoned
evicting pod "coredns-6955765f44-2rhkh"
pod/coredns-6955765f44-2rhkh evicted
node/rhel1 evicted
```

Back to _rhel1_:

```bash
yum install -y kubeadm-1.18.5-0 --disableexcludes=kubernetes

kubeadm upgrade node

yum install -y kubelet-1.18.5-0 kubectl-1.18.5-0 --disableexcludes=kubernetes

systemctl restart kubelet
systemctl daemon-reload
```

Back to the master:  

```bash
$ kubectl uncordon rhel1
node/rhel1 uncordoned

$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.18.5
rhel2   Ready    <none>   294d   v1.17.11
rhel3   Ready    master   294d   v1.18.5
```

You now can repeat this procedure on the second worker node, until you get to:

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.18.5
rhel2   Ready    <none>   294d   v1.18.5
rhel3   Ready    master   294d   v1.18.5
```

Tadaaa again !

## What's next

You can now go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?