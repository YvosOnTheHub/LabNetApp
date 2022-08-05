#########################################################################################
# SCENARIO 21: Persistent Volumes and vClusters.
#########################################################################################

Virtual Clusters (https://www.vcluster.com/) from https://loft.sh are quite an interesting piece of technology.  
They look & taste like real clusters, as you basically have access to everything (admin role, with your own set of APIs), but its construct reside in the namespace of an underlying Kubernetes cluster.

This has many advantages, especially when you dig into all the options you have at hand

- speed of deployment or retirement of a vCluster (just a few seconds, litteraly)
- resource management done in the underlying Kubernetes cluster (choose how many nodes you will run onto, quotas & limits management, ...)
- isolation (with pod security)
- ...

When it comes to storage management, especially in the K8S-aaS context, often comes on the table the question of who will manage the storage & how...  
Trident is fully integrated into Kubernetes, which is great, however some dont want to give access to the Trident configuration to the end-user.  

vClusters could definitely help:

- The storage class is managed by default on the underlying cluster, and can optionally be customized at the vCluster level
- Trident being part of the underlying cluster cannot be modified by the end-user
- Resource Quotas & LimitRanges can be applied to a vCluster to control storage consumption by the Kubernetes admin

Let's see this in action! We are going to create 2 vClusters in this environment:

<p align="center"><img src="Images/1_vclusters_high_level.jpg"></p>

## A. Install vCluster

This is really the easiest thing ever... In short, download & use:

```bash
curl -s -L "https://github.com/loft-sh/vcluster/releases/v0.11.0" | sed -nE 's!.*"([^"]*vcluster-linux-amd64)".*!https://github.com\1!p' | xargs -n 1 curl -L -o vcluster && chmod +x vcluster;
mv vcluster /usr/local/bin
```

To get more information, you can refer to https://www.vcluster.com/docs/getting-started/setup 

## B. Create vClusters

Virtual clusters can be created on one node (default behavior), a subset of Kubernetes nodes (based on labels), or on all of them.  
We have already set some labels for the purporse of this exercise.  

We are now ready to create 2 virtual clusters !  
The admin can deeply customize the setup of the vClusters through the use of a parameter YAML file.  
In my case, I have specified a resource limit for the Control Planes & the labels to look for on the nodes.  

I have also used the following arguments:

- _expose_: the vCluster will be reachable through a LoadBalancer service (ie IP address given by MetalLB)
- _connect=false_: will not automatically connect to the cluster after the creation is successful

```bash
$ vcluster create vcluster-1 -n vc1 -f ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/vcluster_vc1.yaml --expose --connect=false
info   Creating namespace vc1
info   Create vcluster vcluster-1...
info   execute command: helm upgrade vcluster-1 https://charts.loft.sh/charts/vcluster-0.11.0.tgz --kubeconfig /tmp/3080364138 --namespace vc1 --install --repository-config='' --values /tmp/976661125 --values /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/vcluster_vc1.yaml
done √ Successfully created virtual cluster vcluster-1 in namespace vc1.
- Use 'vcluster connect vcluster-1 --namespace vc1' to access the virtual cluster
- Use `vcluster connect vcluster-1 --namespace vc1 -- kubectl get ns` to run a command directly within the vcluster

$ vcluster create vcluster-2 -n vc2 -f ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/vcluster_vc2.yaml --expose --connect=false
info   Creating namespace vc2
info   Create vcluster vcluster-2...
info   execute command: helm upgrade vcluster-1 https://charts.loft.sh/charts/vcluster-0.11.0.tgz --kubeconfig /tmp/1639504954 --namespace vc2 --install --repository-config='' --values /tmp/2943026640 --values /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/vcluster_vc2.yaml
done √ Successfully created virtual cluster vcluster-2 in namespace vc2.
- Use 'vcluster connect vcluster-2 --namespace vc2' to access the virtual cluster
- Use `vcluster connect vcluster-2 --namespace vc2 -- kubectl get ns` to run a command directly within the vcluster

$ vcluster list
NAME         NAMESPACE   STATUS    CONNECTED   CREATED                         AGE
 vcluster-1   vc1         Running               2022-08-02 09:43:13 +0000 UTC   9m18s
 vcluster-2   vc2         Running               2022-08-02 09:51:48 +0000 UTC   43s

$ kubectl get -n vc1 pod -o wide
NAME                                                  READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
coredns-55bd85cf4b-9h5sv-x-kube-system-x-vcluster-1   1/1     Running   0          17m   192.168.24.32   rhel1   <none>           <none>
vcluster-1-0                                          2/2     Running   0          18m   192.168.24.34   rhel1   <none>           <none>

$ kubectl get -n vc2 pod -o wide
NAME                                                  READY   STATUS    RESTARTS   AGE     IP               NODE    NOMINATED NODE   READINESS GATES
coredns-55bd85cf4b-4wkkt-x-kube-system-x-vcluster-1   1/1     Running   0          9m30s   192.168.24.201   rhel2   <none>           <none>
vcluster-2-0                                          2/2     Running   0          10m     192.168.24.48    rhel1   <none>           <none>
```

The _vcluster_ pod is the "control plane" of your tenant, which runs K3S.  
You may wonder what the other POD is? It is the system POD running in the vCluster _kube-system_ namespace but viewed from a different perspective, directly on the host cluster in the vCluster namespace. In order to recognize the different resources on the host cluster, the following naming convention is applied: PODNAME-x-NAMESPACE-x-VCLUSTER

```bash
$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get pod -A
NAMESPACE     NAME                       READY   STATUS    RESTARTS   AGE
kube-system   coredns-55bd85cf4b-9h5sv   1/1     Running   0          20m
```

Our two vClusters are now up & running. Let's look closely at what we have here in the first one:

```bash
$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get nodes -o wide
NAME    STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                                      KERNEL-VERSION          CONTAINER-RUNTIME
rhel2   Ready    <none>   20m   v1.22.3   10.103.111.65   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel1   Ready    <none>   20m   v1.22.3   10.97.93.139    <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get namespaces
NAME              STATUS   AGE
default           Active   21m
kube-system       Active   21m
kube-public       Active   21m
kube-node-lease   Active   21m

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get svc -A
NAMESPACE     NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                  AGE
default       kubernetes   ClusterIP   10.107.102.144   <none>        443/TCP                  21m
kube-system   kube-dns     ClusterIP   10.104.169.59    <none>        53/UDP,53/TCP,9153/TCP   21m

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get crd
NAME                              CREATED AT
addons.k3s.cattle.io              2022-08-02T09:43:30Z
helmcharts.helm.cattle.io         2022-08-02T09:43:30Z
helmchartconfigs.helm.cattle.io   2022-08-02T09:43:30Z

$ vcluster connect vcluster-1 --namespace vc1 -- kubectl get sc
No resources found in default namespace.
```

A few things to notice:

- It looks like a brand new K3S cluster
- There is no Trident resource in the vCluster, nor storage class, as these are managed directly from the underlying cluster
- From a vCluster standpoint, the nodes INTERNAL IP are different from the once you find using the _kubectl get nodes_ command on the underlying cluster

In order to create Persistent Volumes, the Kubernetes admin will have to provide the vCluster admin or the end-users with the right Storage Class to use. Note that you can also create customer storage classes within the vCluster.  

## C. Use vClusters

I would recommend looking into how to connect to a vCluster to see the extent of what it possible: https://www.vcluster.com/docs/getting-started/connect.  
Let's create the kubeconfig files related to each vCluster:

```bash
$ vcluster connect vcluster-1 -n vc1 --kube-config ~/kubeconfig_vc1 --update-current=false
info   Using vcluster vcluster-1 load balancer endpoint: 192.168.0.140
done √ Virtual cluster kube config written to: /root/kubeconfig_vc1
- Use `kubectl --kubeconfig /root/kubeconfig_vc1 get namespaces` to access the vcluster

$ vcluster connect vcluster-2 -n vc2 --kube-config ~/kubeconfig_vc2 --update-current=false
info   Using vcluster vcluster-1 load balancer endpoint: 192.168.0.141
done √ Virtual cluster kube config written to: /root/kubeconfig_vc2
- Use `kubectl --kubeconfig /root/kubeconfig_vc2 get namespaces` to access the vcluster
```

The vCluster admin & end-users would be provided with their own kubeconfig file to use, which can be exported in the KUBECONFIG variable.  
In this lab, I will just use the parameter _--kubeconfig_ with the kubectl command in order to avoir juggling with multiple terminals.

As a vCluster admin, let's first check what we have:

```bash
$ kubectl --kubeconfig ~/kubeconfig_vc1 get nodes -o wide
NAME    STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                                      KERNEL-VERSION          CONTAINER-RUNTIME
rhel2   Ready    <none>   23m   v1.22.3   10.103.111.65   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel1   Ready    <none>   23m   v1.22.3   10.97.93.139    <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
```

Let's install Ghost on this vCluster. For that, you can use the _ghost_vc1.sh_ file from the Ghost_vc1 directory.  
It will be installed in its own namespace called _ghostvc1_.  
Since this application's service is of LoadBalancer type, the script retrieves the IP address & sets it in the pod.

```bash
$ sh Ghost_vc1/ghost_vc1.sh
namespace/ghostvc1 created
persistentvolumeclaim/blog-content-vc1 created
service/blog-vc1 created
deployment.apps/blog-vc1 created

$ kubectl --kubeconfig ~/kubeconfig_vc1 -n ghostvc1 get svc,pod,pvc
NAME               TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/blog-vc1   LoadBalancer   10.102.157.98   192.168.0.142   80:31930/TCP   119s

NAME                            READY   STATUS    RESTARTS   AGE
pod/blog-vc1-6c78b9fb9d-9pct6   1/1     Running   0          118s

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
persistentvolumeclaim/blog-content-vc1   Bound    pvc-42c63348-2629-4242-82eb-f0795801ee2e   5Gi        RWX            sc-tenant1       119s
```

You can now connect to the IP address provided to the Ghost service by the LoadBalancer in order to use this app (192.168.0.142 in this example).  
Let's see what corresponding resources we have on the underlying cluster:

```bash
$ kubectl get -n vc1 pod,svc,pvc -l vcluster.loft.sh/namespace=ghostvc1
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/blog-vc1-6c78b9fb9d-9pct6-x-ghostvc1-x-vcluster-1   1/1     Running   0          2m36s

NAME                                       TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/blog-vc1-x-ghostvc1-x-vcluster-1   LoadBalancer   10.102.157.98   192.168.0.142   80:31930/TCP   2m37s

NAME                                                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
persistentvolumeclaim/blog-content-vc1-x-ghostvc1-x-vcluster-1   Bound    pvc-42c63348-2629-4242-82eb-f0795801ee2e   5Gi        RWX            sc-tenant1       2m37s
```

Here again we see the same resources, but from a different perspective & with a different naming convention.  
The vCluster2 could also decide to deploy Ghost (with the script ghost_vc2.sh in the Ghost_vc2 folder).

<p align="center"><img src="Images/2_vclusters_ghost.jpg"></p>

## D. What about CSI Snapshots

If the current setup does not yet have a volume snapshot class at the cluster level, you can find in the Scenario13 folder:

```bash
$ kubectl create -f ../Scenario13/sc-volumesnapshot.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class created
```

This volume snapshot class can be made available through the vcluster parameter _volumesnapshots:enabled:true_ (already set here).  
Let's create a CSI snapshot & a new PVC from it.  

```bash
$ kubectl --kubeconfig ~/kubeconfig_vc1 -n ghostvc1 get volumesnapshotclass
NAME                                                         DRIVER                  DELETIONPOLICY   AGE
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class   csi.trident.netapp.io   Delete           42s

$ kubectl --kubeconfig ~/kubeconfig_vc1 -n ghostvc1 create -f Ghost_vc1/pvc_snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/blog-content-vc1-snapshot created

$ kubectl --kubeconfig ~/kubeconfig_vc1 -n ghostvc1 get pvc,volumesnapshot
NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
persistentvolumeclaim/blog-content-vc1   Bound    pvc-b62d4555-69c0-449e-a05e-d40dc06d7ed1   5Gi        RWX            sc-tenant1       9m32s

NAME                                                     READYTOUSE   SOURCEPVC          SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
volumesnapshot.snapshot.storage.k8s.io/blog-content-vc1-snapshot   true         blog-content-vc1                           744Ki         csi-snap-class   snapcontent-cb084431-baff-4ce9-b34f-5a39f50e58c2   57s            56s

$ kubectl --kubeconfig ~/kubeconfig_vc1 -n ghostvc1 create -f Ghost_vc1/pvc_from_snap.yaml
persistentvolumeclaim/blog-content-vc1-from-snap created

$ kubectl --kubeconfig ~/kubeconfig_vc1 -n ghostvc1 get pvc
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
blog-content-vc1             Bound    pvc-b62d4555-69c0-449e-a05e-d40dc06d7ed1   5Gi        RWX            sc-tenant1       11m
blog-content-vc1-from-snap   Bound    pvc-a08d87bb-144f-4f7a-9a22-33fdd78f8766   5Gi        RWX            sc-tenant1       12s
```

There you go. We just saw how to easily give access to CSI snapshots to a vCluster user. 

## E. Clean up

Deleting the vClusters is pretty straight forward. Note that all resources created within the vCluster will also be deleted:

```bash
$ vcluster delete vcluster-1 -n vc1 --delete-namespace
info   Delete vcluster vcluster-1...
done √ Successfully deleted virtual cluster vcluster-1 in namespace vc1
done √ Successfully deleted virtual cluster namespace vc1

$ vcluster delete vcluster-2 -n vc2 --delete-namespace
info   Delete vcluster vcluster-2...
done √ Successfully deleted virtual cluster vcluster-2 in namespace vc2
done √ Successfully deleted virtual cluster namespace vc2
```

## What's next

You can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)