#########################################################################################
# ADDENDA 1: Add a node to the cluster
#########################################################################################

**GOAL:**  
Some exercices may benefit from a bigger cluster size (ex: Scenario13: StatefulSets).  
The LabOnDemand has a few unix hosts, but only 3 are part of the Kubernetes cluster.  
This addenda will provide you with all the commands to run to bring a new node into the Kubernetes cluster.  

First, we need to start the _rhel4_ host.  
This can be achieved by using the _VM STatus_ button in the LoD portal (page: MyLabs).  
From there, you can just click on the _Power on_ button next to the RHEL4 line.  

Once on, you can log back into the lab and start configuring this new host.  
Most of the pre-work has already been done, so you basically just need to join _rhel4_ to the cluster.  

Adding a nodes to a cluster with Kubeadm requires generating a new token on the master node **rhel3**:  
```bash
$ kubeadm token create --print-join-command
kubeadm join 192.168.0.63:6443 --token ij4ukd.p4ghhhup7wuaoz0l --discovery-token-ca-cert-hash sha256:278b2ccdb1dccbbbcc67bb7a9748063bd0d9e5f2510147052a6976dab01c8d3f
```

The list of tokens can easily be retrieved with the following:  
```bash
$ kubeadm token list
TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION                                                EXTRA GROUPS
ij4ukd.p4ghhhup7wuaoz0l   23h         2024-07-16T06:48:58Z   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token
```

Now that we have the command to run on **rhel4**, it's time to join the cluster!
```bash
$  kubeadm join 192.168.0.63:6443 --token ij4ukd.p4ghhhup7wuaoz0l --discovery-token-ca-cert-hash sha256:278b2ccdb1dccbbbcc67bb7a9748063bd0d9e5f2510147052a6976dab01c8d3f
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

Now, you can go back to the master (ie _rhel3_), and wait for the new node to be totally available  
```bash
$ kubectl get nodes
NAME    STATUS   ROLES           AGE   VERSION
rhel1   Ready    <none>          78d   v1.29.4
rhel2   Ready    <none>          78d   v1.29.4
rhel3   Ready    control-plane   78d   v1.29.4
rhel4   Ready    <none>          41s   v1.29.4
win1    Ready    <none>          78d   v1.29.4
win2    Ready    <none>          78d   v1.29.4
```

Tadaaaa!!  

If you are planning on testing the CSI Topology feature, you also need to create the labels on this new node.  
As Trident contains a DaemonSet, it will create one of these objects on RHEL4 before you can take care of the topology labels.  
In order to take them into account, you must restart the Trident Controller (of kind Deployment) by simply deleting the current pod.

```bash
kubectl label node rhel4 "topology.kubernetes.io/region=east"
kubectl label node rhel4 "topology.kubernetes.io/zone=east1"
kubectl delete -n trident pod -l app=controller.csi.trident.netapp.io
```

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?