#########################################################################################
# SCENARIO 8: Consumption control: Kubernetes Resource Quotas
#########################################################################################

In order to restrict the tests to a small environment & not affect other projects, we will create a specific namespace called _quota_  
We will then create two types of quotas:

1. limit the number of PVC a user can create
2. limit the total capacity a user can create  

We consider that the ONTAP-NAS backend & storage class have already been created. ([cf Scenario02](../../Scenario02))

```bash
$ kubectl create namespace quota
namespace/quota created
$ kubectl create -n quota -f rq-pvc-count-limit.yaml
resourcequota/pvc-count-limit created
$ kubectl create -n quota -f rq-sc-resource-limit.yaml
resourcequota/sc-resource-limit created

$ kubectl get resourcequota -n quota
NAME                CREATED AT
pvc-count-limit     2020-04-01T08:48:38Z
sc-resource-limit   2020-04-01T08:48:44Z

$ kubectl describe quota pvc-count-limit -n quota
Name:                                                                 pvc-count-limit
Namespace:                                                            quota
Resource                                                              Used  Hard
--------                                                              ----  ----
persistentvolumeclaims                                                0     5
storage-class-nas.storageclass.storage.k8s.io/persistentvolumeclaims  0     3
```

Now let's start creating some PVC against the storage class _quota_ & check the resource quota usage
![Scenario08_1](../Images/scenario08_1.JPG "Scenario08_1")

```bash
$ kubectl create -n quota -f pvc-quotasc-1.yaml
persistentvolumeclaim/quotasc-1 created
$ kubectl create -n quota -f pvc-quotasc-2.yaml
persistentvolumeclaim/quotasc-2 created

$ kubectl describe quota pvc-count-limit -n quota
Name:                                                                 pvc-count-limit
Namespace:                                                            quota
Resource                                                              Used  Hard
--------                                                              ----  ----
persistentvolumeclaims                                                2     5
storage-class-nas.storageclass.storage.k8s.io/persistentvolumeclaims  2     3

$ kubectl create -n quota -f pvc-quotasc-3.yaml
persistentvolumeclaim/quotasc-3 created

$ kubectl describe quota pvc-count-limit -n quota
Name:                                                                 pvc-count-limit
Namespace:                                                            quota
Resource                                                              Used  Hard
--------                                                              ----  ----
persistentvolumeclaims                                                3     5
storage-class-nas.storageclass.storage.k8s.io/persistentvolumeclaims  3     3
```

Logically, you got the maximum number of PVC allowed for this storage class. Let's see what happens next...

```bash
$ kubectl create -n quota -f pvc-quotasc-4.yaml
Error from server (Forbidden): error when creating "quotasc-4.yaml": persistentvolumeclaims "quotasc-4" is forbidden: exceeded quota: pvc-count-limit, requested: storage-class-nas.storageclass.storage.k8s.io/persistentvolumeclaims=1, used: storage-class-nas.storageclass.storage.k8s.io/persistentvolumeclaims=3, limited: storage-class-nas.storageclass.storage.k8s.io/persistentvolumeclaims=3
```

As expected, you cannot create a new PVC in this storage class...
Let's clean up the PVC

```bash
$ kubectl delete pvc -n quota --all
persistentvolumeclaim "quotasc-1" deleted
persistentvolumeclaim "quotasc-2" deleted
persistentvolumeclaim "quotasc-3" deleted
```

Time to look at the capacity quotas  
![Scenario08_2](../Images/scenario08_2.JPG "Scenario08_2")

```bash
$ kubectl describe quota sc-resource-limit -n quota
Name:                                                           sc-resource-limit
Namespace:                                                      quota
Resource                                                        Used  Hard
--------                                                        ----  ----
requests.storage                                                0     10Gi
storage-class-nas.storageclass.storage.k8s.io/requests.storage  0     8Gi
```

Each PVC you are going to use is 5GB.

```bash
$ kubectl create -n quota -f pvc-5Gi-1.yaml
persistentvolumeclaim/5gb-1 created

$ kubectl describe quota sc-resource-limit -n quota
Name:                                                           sc-resource-limit
Namespace:                                                      quota
Resource                                                        Used  Hard
--------                                                        ----  ----
requests.storage                                                5Gi   10Gi
storage-class-nas.storageclass.storage.k8s.io/requests.storage  5Gi   8Gi
```

Seeing the size of the second PVC file, the creation should fail in this namespace

```bash
$ kubectl create -n quota -f pvc-5Gi-2.yaml
Error from server (Forbidden): error when creating "pvc-5Gi-2.yaml": persistentvolumeclaims "5gb-2" is forbidden: exceeded quota: sc-resource-limit, requested: storage-class-nas.storageclass.storage.k8s.io/requests.storage=5Gi, used: storage-class-nas.storageclass.storage.k8s.io/requests.storage=5Gi, limited: storage-class-nas.storageclass.storage.k8s.io/requests.storage=8Gi
```

Before starting the second part of this scenarion, let's clean up

```bash
$ kubeclt delete pvc -n quota 5gb-1
persistentvolumeclaim "5gb-1" deleted
$ kubectl delete resourcequota -n quota --all
resourcequota "pvc-count-limit" deleted
resourcequota "sc-resource-limit" deleted
```

## What's next

You can now move on to the next section of this chapter: [Trident parameters](../2_Trident_parameters)

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)