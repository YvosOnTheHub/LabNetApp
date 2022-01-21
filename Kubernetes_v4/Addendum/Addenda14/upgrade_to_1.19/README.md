#########################################################################################
# ADDENDA 14: Upgrade to 1.19
#########################################################################################

**GOAL:**  
You are currently running Kubernetes 1.18 & would like to upgrade to 1.19.  
Note that this folder contains an _all_in_one.sh_ script that can perform all these steps for you.  

```bash
$ yum install -y kubeadm-1.19.16-0 kubelet-1.19.16-0 kubectl-1.19.16-0 --disableexcludes=kubernetes

$ kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.16", GitCommit:"e37e4ab4cc8dcda84f1344dda47a97bb1927d074", GitTreeState:"clean", BuildDate:"2021-10-27T16:24:44Z", GoVersion:"go1.15.15", Compiler:"gc", Platform:"linux/amd64"}

$ kubeadm upgrade plan
...
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       AVAILABLE
kubelet     3 x v1.18.6   v1.19.16

Upgrade to the latest stable version:

COMPONENT                 CURRENT   AVAILABLE
kube-apiserver            v1.18.6   v1.19.16
kube-controller-manager   v1.18.6   v1.19.16
kube-scheduler            v1.18.6   v1.19.16
kube-proxy                v1.18.6   v1.19.16
CoreDNS                   1.6.7     1.7.0
etcd                      3.4.3-0   3.4.13-0

You can now apply the upgrade by executing the following command:

        kubeadm upgrade apply v1.19.16


$ kubeadm upgrade apply v1.19.16 -y
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.19.16"
[upgrade/versions] Cluster version: v1.18.6
[upgrade/versions] kubeadm version: v1.19.16
...
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.19.16". Enjoy!

$ sed -i 's/VolumeSnapshotDataSource/GenericEphemeralVolume/' /etc/sysconfig/kubelet
$ systemctl daemon-reload
$ systemctl restart kubelet


$ kubectl get nodes
NAME    STATUS   ROLES    AGE   VERSION
rhel1   Ready    <none>   87d   v1.18.6
rhel2   Ready    <none>   87d   v1.18.6
rhel3   Ready    master   87d   v1.19.16
```

Let's process with the worker node _rhel1_.  

```bash
kubeadm-1.19.16-0 kubelet-1.19.16-0 kubectl-1.19.16-0 --disableexcludes=kubernetes
kubeadm upgrade node
sed -i 's/$/--feature-gates=GenericEphemeralVolume=true/' /etc/sysconfig/kubelet
systemctl daemon-reload
systemctl restart kubelet
```

Back to the master after a few seconds:  

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE   VERSION
rhel1   Ready    <none>   87d   v1.19.16
rhel2   Ready    <none>   87d   v1.18.6
rhel3   Ready    master   87d   v1.19.16
```

You now can repeat this procedure on the second worker node, until you get to:

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE   VERSION
rhel1   Ready    <none>   87d   v1.19.16
rhel2   Ready    <none>   87d   v1.19.16
rhel3   Ready    master   87d   v1.19.16
```

Last, we also want to enable the Generic Ephemeral Volume feature gate. This can be done by editing some static manifests on the master node:

```bash
sed -i '/apiserver.key/a \ \ \ \ - --feature-gates=GenericEphemeralVolume=true' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/port=0/a \ \ \ \ - --feature-gates=GenericEphemeralVolume=true' /etc/kubernetes/manifests/kube-scheduler.yaml
sed -i '/use-service-account-credentials=true/a \ \ \ \ - --feature-gates=GenericEphemeralVolume=true' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Kubernetes regularly checks the /etc/kubernetes/manifests folder to check for updates & automatically applies them.  
You should then see 3 PODs relaunched within a minute

```bash
$ kubectl -n kube-system get pod -l tier=control-plane
NAME                            READY   STATUS    RESTARTS   AGE
etcd-rhel3                      1/1     Running   1          10m
kube-apiserver-rhel3            1/1     Running   0          3m37s
kube-controller-manager-rhel3   1/1     Running   0          3m4s
kube-scheduler-rhel3            1/1     Running   0          2m45s

$ kubectl -n kube-system describe pod kube-scheduler-rhel3 | grep -i eph
      --feature-gates=GenericEphemeralVolume=true
```

Tadaaa again !

## What's next

You can now go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?