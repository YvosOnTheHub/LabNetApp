#########################################################################################
# ADDENDA 14: Upgrade to 1.31
#########################################################################################

**GOAL:**  
You are currently running Kubernetes 1.30 & would like to upgrade to 1.31.  
Note that this folder contains an *all_in_one.sh* script that can perform all these steps for you, however only for the linux nodes.  

Let's start by taking care of the Control Plane (_rhel3_).  

Nowadays, the Kubernetes repo are version dependant.  
This means that you first need to modify the repo address, in order for the upgrade to fetch the correct files:  
```bash
sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo
```

This page will guide you through the upgrade to the minor version _1.31.11_. However, if you would to use a different minor version, you can use the following command to list all available packages:  
```bash
yum list --showduplicates kubeadm --disableexcludes=kubernetes
```

The following set of commands must of performed on the Control Plane (ie _rhel3_)
```bash
$ yum install -y kubeadm-1.31.11-150500.1.1 kubelet-1.31.11-150500.1.1 kubectl-1.31.11-150500.1.1 --disableexcludes=kubernetes

$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"31", GitVersion:"v1.31.11", GitCommit:"7e94e1ce5c71407a782db8ef701e290bb0246da0", GitTreeState:"clean", BuildDate:"2025-07-15T18:12:45Z", GoVersion:"go1.23.10", Compiler:"gc", Platform:"linux/amd64"}

$ kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE      CURRENT    TARGET
kubelet     rhel1     v1.30.14   v1.31.11
kubelet     rhel2     v1.30.14   v1.31.11
kubelet     rhel3     v1.30.14   v1.31.11
kubelet     win1      v1.30.14   v1.31.11
kubelet     win2      v1.30.14   v1.31.11

Upgrade to the latest stable version:

COMPONENT                 NODE      CURRENT    TARGET
kube-apiserver            rhel3     v1.30.14   v1.31.11
kube-controller-manager   rhel3     v1.30.14   v1.31.11
kube-scheduler            rhel3     v1.30.14   v1.31.11
kube-proxy                          1.30.14    v1.31.11
CoreDNS                             v1.11.3    v1.11.3
etcd                      rhel3     3.5.15-0   3.5.15-0

You can now apply the upgrade by executing the following command:

        kubeadm upgrade apply v1.31.11
...

$ kubeadm upgrade apply v1.31.11 -y
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.31.11"
[upgrade/versions] Cluster version: v1.30.14
[upgrade/versions] kubeadm version: v1.31.11
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.31.11". Enjoy!
[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```
The control plan upgrade is almost finalized. You just need to restart the Kubelet service to take into account the new version.  
Restart Kubelet takes a few seconds to complete. However it is also recommend to isolate (drain/uncordon) that node beforehand:    
```bash
$ kubectl drain rhel3 --ignore-daemonsets --delete-emptydir-data
node/rhel3 drained
$ systemctl daemon-reload
$ systemctl restart kubelet
$ kubectl uncordon rhel3
node/rhel3 uncordoned

$ kubectl get nodes
NAME    STATUS   ROLES           AGE    VERSION
rhel1   Ready    <none>          451d   v1.30.14
rhel2   Ready    <none>          451d   v1.30.14
rhel3   Ready    control-plane   451d   v1.31.11
win1    Ready    <none>          451d   v1.30.14
win2    Ready    <none>          451d   v1.30.14
```

Let's process with the worker node _rhel1_, on which you need to connect to run the 3 following commands:  
```bash
sed -i 's/1.30/1.31/' /etc/yum.repos.d/kubernetes.repo
yum install -y kubeadm-1.31.11-150500.1.1 kubelet-1.31.11-150500.1.1 kubectl-1.31.11-150500.1.1 --disableexcludes=kubernetes
kubeadm upgrade node
```
Next, you need to restart Kubelet. Note that is also good practice to isolate the worker node (drain/uncordon).  
The 4 next commands can be executed on the control plane (_rhel3_)
```bash
kubectl drain rhel1 --ignore-daemonsets --delete-emptydir-data
ssh -o "StrictHostKeyChecking no" root@rhel1  systemctl daemon-reload
ssh -o "StrictHostKeyChecking no" root@rhel1  systemctl restart kubelet
kubectl uncordon rhel1
```

After a few seconds, you will see the following, which means the first worker node was succesfully updated:  
```bash
$ kubectl get nodes
NAME    STATUS   ROLES           AGE    VERSION
rhel1   Ready    <none>          451d   v1.31.11
rhel2   Ready    <none>          451d   v1.30.14
rhel3   Ready    control-plane   451d   v1.31.11
win1    Ready    <none>          451d   v1.30.14
win2    Ready    <none>          451d   v1.30.14
```

You now can repeat this procedure on the second linux worker node (_rhel2_), until you get to:  
```bash
$ kubectl get nodes
NAME    STATUS   ROLES           AGE    VERSION
rhel1   Ready    <none>          451d   v1.31.11
rhel2   Ready    <none>          451d   v1.31.11
rhel3   Ready    control-plane   451d   v1.31.11
win1    Ready    <none>          451d   v1.30.14
win2    Ready    <none>          451d   v1.30.14
```

If you also want to upgrade the Windows nodes (_win1_ & _win2_), it is good practice to drain each node before performing the task:  
```bash
$ kubectl drain win1 --ignore-daemonsets
node/win1 cordoned
node/win1 drained
```
To move on with the upgrade, you can use the Remote Desktop Connection to access those hosts, and run the following commands in a powershell window:  
```powershell
curl.exe -Lo c:\k\kubeadm.exe  "https://dl.k8s.io/v1.31.11/bin/windows/amd64/kubeadm.exe"
kubeadm upgrade node

stop-service kubelet
curl.exe -Lo c:\k\kubelet.exe "https://dl.k8s.io/v1.31.11/bin/windows/amd64/kubelet.exe"
restart-service kubelet
```

The remaining tasks must be done on the control plane.  

You can now uncordon this worker node:  
```bash
$ kubectl uncordon win1
node/win1 uncordoned
```

Next, apply the same method to the second Windows node _win2_.

Last, you also need to update the Windows Kube Proxy, which runs as a Daemonset:  
```bash
$ kubectl -n kube-system patch daemonset kube-proxy-windows --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "sigwindowstools/kube-proxy:v1.31.11-calico-hostprocess"}]'
daemonset.apps/kube-proxy-windows patched
```

Finally, you should now see the following on the control plane:  
```bash
$ kubectl get nodes
NAME    STATUS   ROLES           AGE    VERSION
rhel1   Ready    <none>          451d   v1.31.11
rhel2   Ready    <none>          451d   v1.31.11
rhel3   Ready    control-plane   451d   v1.31.11
win1    Ready    <none>          451d   v1.31.11
win2    Ready    <none>          451d   v1.31.11
```

Tadaaa, all the nodes are up to date !

## What's next

You can now go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?