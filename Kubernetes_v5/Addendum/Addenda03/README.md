#########################################################################################
# ADDENDA 3: How to deploy User PODs on the master node
#########################################################################################

**GOAL:**  
In most production environments, you will reserve nodes for _management_ workloads & others for _user_ workloads.  
In this environment, we have a 3 nodes cluster made of 1 master node & 2 worker nodes. The master node probably has enough resources to add some extra workloads.  
However, by default, a user POD cannot run on a _master_ node.  
This seggregation is done through the mechanisms of *Taints* & *Tolerations*:  
https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/

## A. Let's look at the environment

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE     VERSION
rhel1   Ready    <none>   87d   v1.22.3
rhel2   Ready    <none>   87d   v1.22.3
rhel3   Ready    master   87d   v1.22.3

$ kubectl describe node rhel3
Name:               rhel3
Roles:              control-plane,master
Labels:             beta.kubernetes.io/arch=amd64
                    beta.kubernetes.io/os=linux
                    kubernetes.io/arch=amd64
                    kubernetes.io/hostname=rhel3
                    kubernetes.io/os=linux
                    node-role.kubernetes.io/control-plane=
                    node-role.kubernetes.io/master=
                    node.kubernetes.io/exclude-from-external-load-balancers=
Annotations:        csi.volume.kubernetes.io/nodeid: {"csi.trident.netapp.io":"rhel3"}
                    kubeadm.alpha.kubernetes.io/cri-socket: /var/run/dockershim.sock
                    node.alpha.kubernetes.io/ttl: 0
                    projectcalico.org/IPv4Address: 192.168.0.63/24
                    projectcalico.org/IPv4IPIPTunnelAddr: 192.168.24.64
                    volumes.kubernetes.io/controller-managed-attach-detach: true
CreationTimestamp:  Wed, 12 Aug 2020 15:47:58 +0000
Taints:             node-role.kubernetes.io/master:NoSchedule
Unschedulable:      false
```

Notice, the _taint_ set to _NoSchedule_, which means that no pod will be able to be schedule on the master.  
To modify this behavior, you need to _untaint_ the node.  

## B. Modify the master to accept PODs.

```bash
$ kubectl taint nodes rhel3 node-role.kubernetes.io/master-
node/rhel3 untainted

$ kubectl describe node rhel3 | grep Taint
Taints:             <none>
```

& Done ! New PODs can be schedule on the master node !

## C. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?