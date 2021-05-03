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

```bash
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

$ reboot
```

Once this host is back online, continue with:

```bash
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=Disabled/' /etc/selinux/config
swapoff -a
```

Last, comment the line for the swap in the  /etc/fstab file

```bash
cp /etc/fstab /etc/fstab.bak
sed -e '/swap/ s/^#*/#/g' -i /etc/fstab
```

## B. Docker Hub user management

If you have not yet read the [Addenda09](../Addenda09) about the Docker Hub management, it would be a good time to do so.  
It is important to preload images on this host, especially because this lab contains some DaemonSets.  
By definition, a daemonset runs on every node of the Kubernetes cluster.
Once the new node has joined the cluster & is ready to be used, new daemonsets will start, but will only succeed if the images are present or if Kubernetes knows what login to use...

In order to have everything ready, you can already pull all the images used in this lab.  
This must be done from _rhel3_ where the script can be found.

```bash
sh ../Addenda09/2_Lazy_Images/pull_all_images.sh rhel4 my_login my_password
```

## C. Install the kubernetes packages & join the cluster

```bash
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
```

The cluster is currently running Kubernetes v1.18.6. We will continue using this version on the new node.  

```bash
yum install -y kubelet-1.18.6 kubeadm-1.18.6 kubectl-1.18.6 --nogpgcheck
```

Before joining this host, you just need to enable *Kubelet*, which is the local Kubernetes agent

```bash
systemctl enable kubelet && systemctl start kubelet
```

Adding a nodes to a cluster with Kubeadm requires generating a new token on the master node **rhel3**:

```bash
$ kubeadm token create --print-join-command
W1108 15:21:51.661071   10046 configset.go:348] WARNING: kubeadm cannot validate component configs for API groups [kubelet.config.k8s.io kubeproxy.config.k8s.io]
kubeadm join 192.168.0.63:6443 --token kfcdvs.mjuo0oxynolklidp --discovery-token-ca-cert-hash sha256:699b2e4d5c4d9f84e8e730e09dda3834d6cc081216529247b3537c58849435a8
```

The list of tokens can easily be retrieved with the following:

```bash
$ kubeadm token list
TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION          EXTRA GROUPS
kfcdvs.mjuo0oxynolklidp   23h         2020-11-09T15:21:51Z   authentication,signing   <none>               system:bootstrappers:kubeadm:default-node-token
```

Now that we have the command to run on **rhel4**, it's time to join the cluster!

```bash
$ kubeadm reset
$ kubeadm join 192.168.0.63:6443 --token kfcdvs.mjuo0oxynolklidp --discovery-token-ca-cert-hash sha256:699b2e4d5c4d9f84e8e730e09dda3834d6cc081216529247b3537c58849435a8
...
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

Now, you can go back to the master (ie _rhel3_), and wait for the new node to be totally available

```bash
$ kubectl get nodes --watch
NAME    STATUS     ROLES    AGE   VERSION
rhel1   Ready      <none>   87d   v1.18.6
rhel2   Ready      <none>   87d   v1.18.6
rhel3   Ready      master   87d   v1.18.6
rhel4   NotReady   <none>   40s   v1.18.6
rhel4   Ready      <none>   41s   v1.18.6
```

Tadaaaa!!

## C. CSI Topology

If you are planning on testing the CSI Topology feature, you also need to create the labels on this new node.  
As Trident contains a DaemonSet, it will create one of these objects on RHEL4 before you can take care of the topology labels.  
In order to take them into account, you must restart the Trident Controller (of kind Deployment) by simply deleting the current pod.

```bash
kubectl label node rhel4 "topology.kubernetes.io/region=trident"
kubectl label node rhel4 "topology.kubernetes.io/zone=west"
kubectl delete -n trident pod -l app=controller.csi.trident.netapp.io
```

## D. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?