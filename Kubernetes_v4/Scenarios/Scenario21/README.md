#########################################################################################
# SCENARIO 21: Persistent Volumes and virtual clusters.
#########################################################################################

Managing Kubernetes with multiple teams, projects, applications, use cases or environments can quickly become cumbersome, especially if each one of these require its own cluster...  

Now, is a dedicated Kubernetes really necessary? Think about it for a second!  

Maybe the reasons for requesting or building new clusters are valid, however, maybe you don't have the resources to provide new clusters, nor the time, even if it takes juste a few minutes...  

Now, what if the end user THINKS he has a dedicated cluster, even though evrything is just virtualized?  

Virtual Clusters (https://www.vcluster.com/) from https://loft.sh are quite an interesting piece of technology.  
They look & taste like real clusters, as you have bascially access to everything (admin role, with your own set of APIs), but its construct reside in the namespace of an underlying cluster.

This has many advantages, especially when you dig into all the options you have at hand

- speed of deployment (just a few seconds, litteraly) or retirement of a vCluster
- resource managment (choose how many nodes you will run onto, quotas & limits management, ...)
- isolation (with pod security)
- ...

When it comes to storage management, especially in the K8S-aaS context, often comes on the table the question of who will manage the storage & how...  
Trident is fully integrated into Kubernetes, which is great, however giving access to the Trident configuration to the end-user may sometimes not be optimal.

vClusters could definitely help:

- The storage class is managed by default on the underlying cluster, and can optionally be customized at the vCluster level
- Trident being part of the underlying cluster cannot be modified by the end-user
- Resource Quotas & LimitRanges can be applied to a vCluster to control storage consumption by the Kubernetes admin

Let's see this in action!

## A. PreRequisites

In order to best benefit from this experiment, you will first need to:

- Install MetalLB: cf [Addenda05](../../Addendum/Addenda05)
- Add an extra node to the Kubernetes cluster: cf [Addenda01](../../Addendum/Addenda01)

With 4 nodes, your cluster will look the following:

```bash
$ kubectl get nodes -o wide
NAME    STATUS   ROLES    AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                                      KERNEL-VERSION          CONTAINER-RUNTIME
rhel1   Ready    <none>   596d    v1.18.6   192.168.0.61   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel2   Ready    <none>   596d    v1.18.6   192.168.0.62   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel3   Ready    master   596d    v1.18.6   192.168.0.63   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel4   Ready    <none>   3d19h   v1.18.6   192.168.0.64   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
```

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario21_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario21_pull_images.sh my_login my_password
```

## B. Storage Configuration

Let's create two new Trident backends associated with specific storage classes, so that we can demonstrate how the Kubernetes admin can control the storage consumption of a vCluster

```bash
$ kubectl create -n trident -f trident_ontap_credentials.yaml
secret/sc21_credentials created

$ kubectl create -n trident -f trident_backend_vc1.yaml
tridentbackendconfig.trident.netapp.io/backend-vc1 created

$ kubectl create -n trident -f trident_backend_vc2.yaml
tridentbackendconfig.trident.netapp.io/backend-vc2 created

$ kubectl create -f sc-vc1.yaml
storageclass.storage.k8s.io/sc-vc1 created

$ kubectl create -f sc-vc2.yaml
storageclass.storage.k8s.io/sc-vc2 created
```

## C. Install vCluster

This is really the easiest thing ever... In short, download & use:

```bash
curl -s -L "https://github.com/loft-sh/vcluster/releases/latest" | sed -nE 's!.*"([^"]*vcluster-linux-amd64)".*!https://github.com\1!p' | xargs -n 1 curl -L -o vcluster && chmod +x vcluster;
mv vcluster /usr/local/bin
```

To get more information, you can refer to https://www.vcluster.com/docs/getting-started/setup 

## D. Create vClusters

Virtual clusters can be created on a subset of Kubernetes nodes (based on labels), or on all of them.  
We will create labels to use the first method:

```bash
$ kubectl label node rhel1 "vcluster1=true"
node/rhel1 labeled
$ kubectl label node rhel3 "vcluster1=true"
node/rhel3 labeled
$ kubectl label node rhel2 "vcluster2=true"
node/rhel2 labeled
$ kubectl label node rhel3 "vcluster2=true"
node/rhel3 labeled
```

We are now ready to create 2 virtual clusters !

```bash
$ vcluster create vcluster-1 -n vc1 -f ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario21/vcluster_vc1.yaml --expose
[info]   Creating namespace vc1
[info]   execute command: helm upgrade vcluster-1 vcluster --repo https://charts.loft.sh --version 0.7.1 --kubeconfig /tmp/918707822 --namespace vc1 --install --repository-config='' --values /tmp/3715143884 --values vcluster_vc1.yaml
[done] √ Successfully created virtual cluster vcluster-1 in namespace vc1.
- Use 'vcluster connect vcluster-1 --namespace vc1' to access the virtual cluster
- Use 'vcluster connect vcluster-1 --namespace vc1 -- kubectl get ns' to run a command directly within the vcluster

$ vcluster create vcluster-2 -n vc2 -f ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario21/vcluster_vc2.yaml --expose
[info]   Creating namespace vc2
[info]   execute command: helm upgrade vcluster-2 vcluster --repo https://charts.loft.sh --version 0.7.1 --kubeconfig /tmp/3188407328 --namespace vc2 --install --repository-config='' --values /tmp/950448126 --values vcluster_vc2.yaml
[done] √ Successfully created virtual cluster vcluster-2 in namespace vc2.
- Use 'vcluster connect vcluster-2 --namespace vc2' to access the virtual cluster
- Use 'vcluster connect vcluster-2 --namespace vc2 -- kubectl get ns' to run a command directly within the vcluster

$ vcluster list
 NAME         NAMESPACE   CREATED                         AGE
 vcluster-1   vc1         2022-04-01 08:05:40 +0000 UTC   5m38s
 vcluster-2   vc2         2022-04-01 08:08:24 +0000 UTC   2m54s
```

I would recommend looking into how to connect to a vCluster to see the extent of what it possible: https://www.vcluster.com/docs/getting-started/connect.  
As there is a LoadBalancer configured, the IP address of the vCluster end-point will be automatically assigned.  
Also, let's create the kubeconfig files related to each vCluster:

```bash
$ vcluster connect vcluster-1 -n vc1 --kube-config ~/kubeconfig_vc1.yaml
[info]   Using vcluster vcluster-1 load balancer endpoint: 192.168.0.140
[info]   Use 'vcluster connect vcluster-1 -n vc1 -- kubectl get ns' to execute a command directly within this terminal
[done] √ Virtual cluster kube config written to: /root/kubeconfig_vc1.yaml. You can access the cluster via 'kubectl --kubeconfig /root/kubeconfig_vc1.yaml get namespaces'

$ vcluster connect vcluster-2 -n vc2 --kube-config ~/kubeconfig_vc2.yaml
[info]   Using vcluster vcluster-2 load balancer endpoint: 192.168.0.141
[info]   Use 'vcluster connect vcluster-2 -n vc2 -- kubectl get ns' to execute a command directly within this terminal
[done] √ Virtual cluster kube config written to: /root/kubeconfig_vc2.yaml. You can access the cluster via 'kubectl --kubeconfig /root/kubeconfig_vc2.yaml get namespaces'
```

Our two vClusters are up & running. Let's look closely at what we have here:

```bash
$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get nodes -o wide
NAME    STATUS   ROLES    AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                                      KERNEL-VERSION          CONTAINER-RUNTIME
rhel1   Ready    <none>   60m     v1.18.6   10.103.188.115   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel3   Ready    master   60m     v1.18.6   10.103.246.161   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get namespaces
NAME              STATUS   AGE
default           Active   45m
kube-system       Active   45m
kube-public       Active   45m
kube-node-lease   Active   45m

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get svc -A
NAMESPACE     NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
default       kubernetes   ClusterIP   10.102.158.21   <none>        443/TCP                  45m
kube-system   kube-dns     ClusterIP   10.96.245.47    <none>        53/UDP,53/TCP,9153/TCP   45m

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get crd
NAME                              CREATED AT
addons.k3s.cattle.io              2022-04-01T08:06:06Z
helmcharts.helm.cattle.io         2022-04-01T08:06:06Z
helmchartconfigs.helm.cattle.io   2022-04-01T08:06:06Z

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get sc
No resources found in default namespace.
```

A few things to notice:

- It looks like a brand new K3S cluster
- There is no Trident resource, nor storage class, as these are managed directly from the underlying cluster
- From a vCluster standpoint, the nodes INTERNAL IP are different from the once you find using the _kubectl get nodes_ command on the underlying cluster

In order to create Persistent Volumes, the Kubernetes admin will have to provide the vCluster admin or the end-users with the right Storage Class to use.

## E. Use vClusters

The vCluster admin & end-users would be provided with their own kubeconfig file to use, which can be exported in the KUBECONFIG variable.  
In this lab, I will just use the parameter --kubeconfig with the kubectl command in order to avoir juggling with multiple terminals.

As a vCluster admin, let's first check what we have:

```bash
$ kubectl --kubeconfig ~/kubeconfig_vc1.yaml get nodes -o wide
NAME    STATUS   ROLES    AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                                      KERNEL-VERSION          CONTAINER-RUNTIME
rhel1   Ready    <none>   59m   v1.18.6   10.103.246.161   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel3   Ready    <none>   59m   v1.18.6   10.103.188.115   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
```

Let's install Ghost on this vCluster. For that, you can use the _ghost_vc1.sh_ file from the Ghost_vc1 directory.  
It will be installed in its own namespace called ghostvc1.  
Since this application's service is of LoadBalancer type, the script retrieves the IP address & sets in the pod.

```bash
$ sh ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario21/Ghost_vc1/ghost_vc1.sh
namespace/ghostvc1 created
persistentvolumeclaim/blog-content-vc1 created
service/blog-vc1 created
deployment.apps/blog-vc1 created

$ kubectl --kubeconfig ~/kubeconfig_vc1.yaml -n ghostvc1 get svc,pod,pvc
```










## What's next

You can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)