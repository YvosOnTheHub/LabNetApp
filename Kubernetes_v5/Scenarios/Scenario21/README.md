#########################################################################################
# SCENARIO 21: Persistent Volumes and Multi Tenancy.
#########################################################################################

Managing Kubernetes with multiple teams, projects, applications, use cases or environments can quickly become cumbersome, especially if each one of these requires its own cluster...  

Now, is a dedicated Kubernetes really necessary? Think about it for a second!  

Maybe the reasons for requesting or building new clusters are valid, however, maybe you don't have the resources to provide new clusters, nor the time, even if it takes juste a few minutes...  

Maybe using one Kubernetes cluster to securely host several teams/projects/applications could save time & budget.

After all, sharing is caring, right ?

We are going to see in this chapter two products that bring solutions to multi-tenancy in Kubernetes:

- Capsule by Clastix.io
- vClusters by Loft.sh

According to **Clastix.io**, _Capsule implements a multi-tenant and policy-based environment in your Kubernetes cluster. It is designed as a micro-services-based ecosystem with the minimalist approach, leveraging only on upstream Kubernetes_  (cf https://capsule.clastix.io/docs/)

The starting point of Capsule was to simplify the Kubernetes namespace concept, which somehow can be use to implement a simple multi tenant environment, but can also come with limitations, especially when it comes to sharing resources.  
Without getting all _inception_ all the way on you, you can see Capsule as a way to better manage resources for tenants made of several namespaces (a tenant of tenants ?!). Or said differently, Tenants can be seen as namespaces on steroids.  

According to **Loft.sh**, _Virtual clusters are fully working Kubernetes clusters that run on top of other Kubernetes clusters. Compared to fully separate "real" clusters, virtual clusters reuse worker nodes and networking of the host cluster. They have their own control plane and schedule all workloads into a single namespace of the host cluster. Like virtual machines, virtual clusters partition a single physical cluster into multiple separate ones_ (cf https://www.vcluster.com/docs/what-are-virtual-clusters)

The Loft.sh approach is a bit different. vClusters look & taste like real clusters, as you basically have access to everything (admin role, with your own set of APIs), but its construct reside in the namespace of an underlying Kubernetes cluster.  
And you thought you had your own dedicated Kubernetes cluster? really ? Think again ...

Before testing both solutions, we will prepare the Trident configuration that can be used by both products:

Let's create two new Trident backends associated with specific storage classes, so that we can demonstrate how the Kubernetes admin can control the storage consumption of a vCluster

```bash
$ kubectl create -n trident -f scenario21_trident_config.yaml
secret/sc21_credentials created
tridentbackendconfig.trident.netapp.io/backend-tenant1 created
tridentbackendconfig.trident.netapp.io/backend-tenant2 created

$ kubectl create -f scenario21_storage_classes.yaml
storageclass.storage.k8s.io/sc-tenant1 created
storageclass.storage.k8s.io/sc-tenant2 created
```

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario21_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario21_pull_images.sh my_login my_password
```

In order to best benefit from this experiment, you will also need to:

- Install MetalLB: cf [Addenda05](../../Addendum/Addenda05)
- Add an extra node to the Kubernetes cluster: cf [Addenda01](../../Addendum/Addenda01)

With 4 nodes, your cluster will look the following:

```bash
$ kubectl get nodes -o wide
NAME    STATUS   ROLES                  AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                                      KERNEL-VERSION          CONTAINER-RUNTIME
rhel1   Ready    <none>                 719d   v1.22.3   192.168.0.61   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel2   Ready    <none>                 263d   v1.22.3   192.168.0.62   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel3   Ready    control-plane,master   719d   v1.22.3   192.168.0.63   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
rhel4   Ready    <none>                 1d1h   v1.22.3   192.168.0.64   <none>        Red Hat Enterprise Linux Server 7.5 (Maipo)   3.10.0-862.el7.x86_64   docker://18.9.1
```

Last, as both solutions can benefit from labels positioned on nodes, we will already configure some:

```bash
$ kubectl label node rhel1 "tenant1=true"
node/rhel1 labeled
$ kubectl label node rhel2 "tenant1=true"
node/rhel2 labeled
$ kubectl label node rhel2 "tenant2=true"
node/rhel2 labeled
$ kubectl label node rhel3 "tenant2=true"
node/rhel3 labeled
```

We are now ready to test both solutions:

[1.](Clastix_Capsule) Capsule by Clastix.io  
[2.](Loft_vClusters) vClusters by Loft.sh  
