#########################################################################################
# SCENARIO 21: Persistent Volumes and Capsule.
#########################################################################################

Namespaces provide a mechanism for isolating groups of resources within a single cluster. Limits & quotas can also be applied to a namespace to control resource consumption (essentially CPU, Memory & Storage). If the mapping user <-> namespace is a 1 to 1 relationship, then control can be easily implemented, to a certain extent. However, if a user or a group of users request several namespaces, the infrastructure admins do not have an easy way to control all of these like one entity.

That is where Capsule from Clastix comes into the game, with the **Tenant** resource.  

With the help of tenants, resources can be controlled & limited accross several namespaces (example: instead of 5 PVC max per namespace, you would have 15 PVC max per Tenant, with a maximum of 3 namespaces).  

More, it is not only about resources. With the help of Capsule, you can also **enable or disable Kubernetes features for a whole tenant**, with really fine grain mechanisms. This applies to (not an exhaustive list):

- node selection
- ingress classes
- storage classes
- network policies
- registries
- service control
- ...

In this scenario, we will see how to install & use Capsule, in conjunction with Astra Trident.

<p align="center"><img src="Images/1_Capsule_high_level.png"></p>

## A. Install Capsule

Capsule can be installed either via Helm chart, or by deploying manually the operator, which is the way we are using here.

```bash
$ kubectl apply -f https://raw.githubusercontent.com/clastix/capsule/v0.1.1/config/install.yaml
namespace/capsule-system created
customresourcedefinition.apiextensions.k8s.io/capsuleconfigurations.capsule.clastix.io created
customresourcedefinition.apiextensions.k8s.io/tenants.capsule.clastix.io created
clusterrolebinding.rbac.authorization.k8s.io/capsule-manager-rolebinding created
secret/capsule-ca created
secret/capsule-tls created
service/capsule-controller-manager-metrics-service created
service/capsule-webhook-service created
deployment.apps/capsule-controller-manager created
capsuleconfiguration.capsule.clastix.io/capsule-default created
mutatingwebhookconfiguration.admissionregistration.k8s.io/capsule-mutating-webhook-configuration created
validatingwebhookconfiguration.admissionregistration.k8s.io/capsule-validating-webhook-configuration created

$ kubectl get -n capsule-system pod
NAME                                              READY   STATUS    RESTARTS   AGE
capsule-controller-manager-5958fcf7cb-jgd75   1/1     Running   0          20h

$ kubectl get crd | grep caps
capsuleconfigurations.capsule.clastix.io              2022-08-02T13:47:27Z
tenants.capsule.clastix.io                            2022-08-02T13:47:27Z
```

By default, different tenants could potentially decide to create namespaces with the same name, which would end up in error if one already exists. 
To avoid such behavior, you can enforce a prefix on each namespace. This is also useful if a tenant owns several namespaces:

```bash
$ kubectl patch capsuleconfigurations.capsule.clastix.io capsule-default --type=merge -p '{"spec": {"forceTenantPrefix": true}}'
capsuleconfiguration.capsule.clastix.io/capsule-default patched
```

## B. Create tenants

As Capsule is fully managed with Kubectl, creating & managing tenants is pretty easy.  
The first Tenant we are going to create contains a few parameters:

- Only allows images from the private registry _registry.demo.netapp.com_
- The user _owner1_ can create & manage up to 3 namespaces
- Apps running in this tenant are limited to nodes with the "tenant1:true" label (essentially nodes RHEL1 & RHEL2)

To learn more about how to configure Capsule, please refer to https://capsule.clastix.io/docs/general/tutorial 

```bash
$ kubectl create -f tenant1.yaml
tenant.capsule.clastix.io/tenant1 created

$ kubectl create -f tenant2.yaml
tenant.capsule.clastix.io/tenant1 created

$ kubectl get tenants
NAME      STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR        AGE
tenant1   Active   3                 0                 {"tenant1":"true"}   12s
tenant2   Active   1                 0                 {"tenant2":"true"}   3s
```

Nothing easier than creating tenants. As you can see, you also have some basic information available when listing the tenants.

## C. Access tenants

Each tenant comes with its own admin (respectively _owner1_ & _owner2_) & group of admins.  
A [script](https://github.com/clastix/capsule/blob/master/hack/create-user.sh) provided by Capsule will create the kubeconfig files for each user. A copy of this script (_create-user.sh_, version 0.1.1) is available in this folder.

```bash
$ sh create-user.sh owner1 tenant1
creating certs in TMPDIR /tmp/tmp.MtzPFBVlF9
merging groups /O=capsule.clastix.io
Generating RSA private key, 2048 bit long modulus
............................+++
...................+++
e is 65537 (0x10001)
certificatesigningrequest.certificates.k8s.io/owner1-tenant1 created
certificatesigningrequest.certificates.k8s.io/owner1-tenant1 approved
kubeconfig file is: owner1-tenant1.kubeconfig
to use it as owner1 export KUBECONFIG=owner1-tenant1.kubeconfig

$ sh create-user.sh owner2 tenant2
creating certs in TMPDIR /tmp/tmp.Z43L1x5IOC
merging groups /O=capsule.clastix.io
Generating RSA private key, 2048 bit long modulus
..................+++
................+++
e is 65537 (0x10001)
certificatesigningrequest.certificates.k8s.io/owner2-tenant2 created
certificatesigningrequest.certificates.k8s.io/owner2-tenant2 approved
kubeconfig file is: owner2-tenant2.kubeconfig
to use it as owner2 export KUBECONFIG=owner2-tenant2.kubeconfig
```

For now, there is not much to list with either users, as we have not created anything yet.  
By the way, these users cannot by default see the available storage classes, as these are cluster wide resources. The Cluster admin must then provide them with the name of the storage class they are allowed to use:

```bash
$ kubectl --kubeconfig owner1-tenant1.kubeconfig get sc
Error from server (Forbidden): storageclasses.storage.k8s.io is forbidden: User "owner1" cannot list resource "storageclasses" in API group "storage.k8s.io" at the cluster scope
```

## D. Use tenants

Let's install Ghost on _tenant1_. For that, you can use the _ghost_tenant1.sh_ file from the Ghost_tenant1 folder.  
It will be installed in its own namespace called _ghosttenant1_.  
Since this application's service is of LoadBalancer type, the script retrieves the IP address & sets it in the pod.

```bash
$ sh Ghost_tenant1/ghost.sh
namespace/tenant1-ghost created
persistentvolumeclaim/blog-content-tenant1 created
service/blog-tenant1 created
deployment.apps/blog-tenant1 created
```

By the way, since I have enforced tenant prefix control, the namespace creation would fail if its name would not start with _tenant1_.  

As a tenant admin, I can know list the resources in the newly created namespace:

```bash
$ kubectl --kubeconfig owner1-tenant1.kubeconfig get svc,pod,pvc -n tenant1-ghost
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
service/blog-tenant1   LoadBalancer   10.103.57.71   192.168.0.140   80:30371/TCP   3m7s

NAME                                READY   STATUS    RESTARTS   AGE
pod/blog-tenant1-69c8b8bf58-qnvx7   1/1     Running   0          3m7s

NAME                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/blog-content-tenant1   Bound    pvc-fda5accc-138b-4410-9a73-1fe61bae29c9   5Gi        RWX            sc-tenant1     3m7s
```

The cluster admin can also list the content of this namespace, & will get the same result:

```bash
$ kubectl get svc,pod,pvc -n tenant1-ghost
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
service/blog-tenant1   LoadBalancer   10.103.57.71   192.168.0.140   80:30371/TCP   3m7s

NAME                                READY   STATUS    RESTARTS   AGE
pod/blog-tenant1-69c8b8bf58-qnvx7   1/1     Running   0          3m7s

NAME                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/blog-content-tenant1   Bound    pvc-fda5accc-138b-4410-9a73-1fe61bae29c9   5Gi        RWX            sc-tenant1     3m7s
```

However, the user of the second tenant will not have the right to list resources from a namespace created by tenant1.

```bash
$ kubectl --kubeconfig owner2-tenant2.kubeconfig get svc,pod,pvc -n tenant1-ghost
Error from server (Forbidden): services is forbidden: User "owner2" cannot list resource "services" in API group "" in the namespace "tenant1-ghost"
Error from server (Forbidden): pods is forbidden: User "owner2" cannot list resource "pods" in API group "" in the namespace "tenant1-ghost"
Error from server (Forbidden): persistentvolumeclaims is forbidden: User "owner2" cannot list resource "persistentvolumeclaims" in API group "" in the namespace "tenant1-ghost"
```

Last, we can also see that the quota count has increased:

```bash
$ kubectl get tenant
NAME      STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR        AGE
tenant1   Active   3                 1                 {"tenant1":"true"}   19h
tenant2   Active   1                 0                 {"tenant2":"true"}   19h
```

## E. What about CSI Snapshots

Capsule does not natively support CSI Snapshots at this time. However, high levels of optimizations can be granted, one could active this feature.

## F. Clean up

Deleting a tenant is pretty straight forward:

```bash
$ kubectl delete tenant tenant1
tenant.capsule.clastix.io "tenant1" deleted

$ kubectl delete tenant tenant2
tenant.capsule.clastix.io "tenant2" deleted
```

## What's next

You can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)