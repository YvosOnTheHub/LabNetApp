#########################################################################################
# ADDENDA 3: How to deploy User PODs on the control plane
#########################################################################################

**GOAL:**  
In most production environments, you will reserve nodes for _management_ workloads & others for _user_ workloads.  
In this environment, we have a 5 nodes cluster made of 1 control plane node, 2 linux worker nodes as well as 2 windows worker nodes. The master node probably has enough resources to add some extra workloads.  
However, by default, a user POD cannot run on a _control-plane_ node.  
This seggregation is done through the mechanisms of *Taints* & *Tolerations*:  
https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/

## A. Let's look at the environment

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE     VERSION
rhel1   Ready    <none>          75d   v1.29.4
rhel2   Ready    <none>          75d   v1.29.4
rhel3   Ready    control-plane   75d   v1.29.4
win1    Ready    <none>          75d   v1.29.4
win2    Ready    <none>          75d   v1.29.4


$ kubectl describe node rhel3
Name:               rhel3
Roles:              control-plane
Labels:             beta.kubernetes.io/arch=amd64
                    beta.kubernetes.io/os=linux
                    kubernetes.io/arch=amd64
                    kubernetes.io/hostname=rhel3
                    kubernetes.io/os=linux
                    node-role.kubernetes.io/control-plane=
                    node.kubernetes.io/exclude-from-external-load-balancers=
                    topology.kubernetes.io/region=us-east1
                    topology.kubernetes.io/zone=us-east1-a
Annotations:        csi.volume.kubernetes.io/nodeid: {"csi.tigera.io":"rhel3","csi.trident.netapp.io":"rhel3"}
                    kubeadm.alpha.kubernetes.io/cri-socket: unix:///var/run/crio/crio.sock
                    node.alpha.kubernetes.io/ttl: 0
                    projectcalico.org/IPv4Address: 192.168.0.63/24
                    projectcalico.org/IPv4VXLANTunnelAddr: 192.168.25.64
                    volumes.kubernetes.io/controller-managed-attach-detach: true
CreationTimestamp:  Sat, 27 Apr 2024 20:35:59 +0000
Taints:             node-role.kubernetes.io/control-plane:NoSchedule
Unschedulable:      false
```

Notice, the _taint_ set to _NoSchedule_, which means that no user pod will be able to be scheduled on the node.  
To modify this behavior, you need to _untaint_ the node.  

## B. Modify the control plane to accept user PODs.

```bash
$ kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule-
node/rhel3 untainted

$ kubectl describe node rhel3 | grep Taint
Taints:             <none>
```

& Done ! New PODs can be schedule on the control plane !

## C. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?