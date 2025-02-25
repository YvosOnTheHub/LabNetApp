#########################################################################################
# SCENARIO 21: Persistent Volumes and Multi Tenancy.
#########################################################################################

Managing Kubernetes with multiple teams, projects, applications, use cases or environments can quickly become cumbersome, especially if each one of these requires its own cluster...  

Now, is a dedicated Kubernetes really necessary? Think about it for a second!  

Maybe the reasons for requesting or building new clusters are valid, however, maybe you don't have the resources to provide new clusters, nor the time, even if it takes juste a few minutes...  

Maybe using one Kubernetes cluster to securely host several teams/projects/applications could save time & budget.

After all, sharing is caring, right ?

We are going to see in this chapter three products that bring solutions to multi-tenancy in Kubernetes:  
- Capsule by Clastix.io  
- Kamaji by Clastix.io  
- vClusters by Loft.sh  

>> According to Clastix.io, Capsule implements a multi-tenant and policy-based environment in your Kubernetes cluster. It is designed as a micro-services-based ecosystem with the minimalist approach, leveraging only on upstream Kubernetes_  (cf https://capsule.clastix.io/docs/)

The starting point of Capsule was to simplify the Kubernetes namespace concept, which somehow can be use to implement a simple multi tenant environment, but can also come with limitations, especially when it comes to sharing resources.  
Without getting all _inception_ all the way on you, you can see Capsule as a way to better manage resources for tenants made of several namespaces (a tenant of tenants ?!). Or said differently, Tenants can be seen as namespaces on steroids.  

Clastix took the concept even further with Kamaji.  
Here, we are going to mutualize all control planes on one single orcherstrator, again to minimize harware consumption & optimize resources.  
Workers nodes can then be added & managed the same way as if you were running a traditional environment.  

>> Kamaji turns any Kubernetes cluster into a “Management Cluster” to orchestrate other Kubernetes clusters called “Tenant Clusters”. Kamaji is special because the Control Plane components are running inside pods instead of dedicated machines. This solution makes running multiple Control Planes cheaper and easier to deploy and operate. (cf https://kamaji.clastix.io/)  

The Loft.sh approach is a bit different. vClusters look & taste like real clusters, as you basically have access to everything (admin role, with your own set of APIs), but its construct reside in the namespace of an underlying Kubernetes cluster.  
And you thought you had your own dedicated Kubernetes cluster? really ? Think again ...  

>> According to Loft.sh, Virtual clusters are fully working Kubernetes clusters that run on top of other Kubernetes clusters. Compared to fully separate "real" clusters, virtual clusters reuse worker nodes and networking of the host cluster. They have their own control plane and schedule all workloads into a single namespace of the host cluster. Like virtual machines, virtual clusters partition a single physical cluster into multiple separate ones (cf https://www.vcluster.com/docs/what-are-virtual-clusters)

Time to jump in all 3 solutions:  
[1.](Clastix_Capsule) Capsule by Clastix.io  
[2.](Clastix_Kamaji) Kamaji by Clastix.io  
[3.](Loft_vClusters) vClusters by Loft.sh  
