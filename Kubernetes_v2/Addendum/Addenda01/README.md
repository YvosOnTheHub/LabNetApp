#########################################################################################
# ADDENDA 1: Add a node to the cluster
#########################################################################################

**GOAL:**   
Some exercices may benefit from a bigger cluster size (ex: Scenario13: StatefulSets).  
The LabOnDemand has 6 unix hosts, but only 3 are part of the Kubernetes cluster.  
This addenda will provide you with all the commands to run to bring a new node into the Kubernetes cluster.

So, let's configure the host _rhel4_ and add it to the cluster.
First, connect to this host with Putty...

## A. Prepare the host (firewall, security)

```
# cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# reboot
```
Once this host is back online, continue with:
```
# setenforce 0
# swapoff -a
```
Last, edit /etc/fstab & comment (\#) the swap line

## B. Install the kubernetes packages & join the cluster

```
# cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
```
Depending on the current version of the Kubernetes cluster, you may choose one command or the other.  
- v1.15.3 is the version that is installed by default in the lab
- v1.17.6 is the target version if you chose to upgrade the cluster [cf Addenda04](https://github.com/YvosOnTheHub/LabNetApp/tree/master/Kubernetes_v2/Addendum/Addenda04)
```
# yum install -y kubelet-1.15.3 kubeadm-1.15.3 kubectl-1.15.3 --nogpgcheck
```
OR
```
# yum install -y kubelet-1.17.6 kubeadm-1.17.6 kubectl-1.17.6 --nogpgcheck
```
Before joining this host, you just need to enable *Kubelet*, which is the local Kubernetes agent
```
# systemctl enable kubelet && systemctl start kubelet
```
Time to join the cluster!
```
# kubeadm reset
# kubeadm join 192.168.0.63:6443 --token 1fpzhb.diqla6g7x83b4iah --discovery-token-ca-cert-hash sha256:8469a0fe236e02b5c4834196a3d85ce1b5352598a824010dced8cb5e0f43f4c5
...
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```
Now, you can go back to the master (ie _rhel3_), and wait for the new node to be totally available
```
# kubectl get nodes --watch
NAME    STATUS     ROLES    AGE    VERSION
rhel1   Ready      <none>   206d   v1.15.3
rhel2   Ready      <none>   206d   v1.15.3
rhel3   Ready      master   206d   v1.15.3
rhel4   NotReady   <none>   40s    v1.15.3
rhel4   Ready      <none>   41s    v1.15.3
```

Tadaaaa!!

If Trident is already installed, you will see that a new POD will start on this new host.  
This is totally expected as CSI Trident is partially composed of DaemonSets, which by definition run on every nodes.
```
# kubectl get pods -n trident -o wide
NAME                           READY   STATUS    RESTARTS   AGE   IP             NODE    NOMINATED NODE   READINESS GATES
trident-csi-5fztb              2/2     Running   0          55s   192.168.0.62   rhel2   <none>           <none>
trident-csi-6b778f79bb-7n4x2   3/3     Running   0          55s   10.39.0.1      rhel4   <none>           <none>
trident-csi-6p67v              2/2     Running   0          55s   192.168.0.64   rhel4   <none>           <none>
trident-csi-khknt              2/2     Running   0          55s   192.168.0.61   rhel1   <none>           <none>
trident-csi-wdmjq              2/2     Running   0          55s   192.168.0.63   rhel3   <none>           <none>
```


## C. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?