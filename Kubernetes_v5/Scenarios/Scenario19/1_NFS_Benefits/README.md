#########################################################################################
# SCENARIO 19: What benefits can RWX & NFS bring over RWO?
#########################################################################################

Shared PVs are by definition good when several PODs must access the same volume.  
Here are a few use cases for RWX:

- Scale-out: if the data sits outside of the POD, the container image will obviously be smaller & then faster to start. Also, scaling this application will only lead to multiplying the PODs, while the data & the volume will not change. A typical example is a Web Frontend, such as WordPress.
- Upgrade: you probably prefer a non-disruptive upgrade of your application... Rolling updates are much easier & faster with shared PVs
- Efficiency: if you were to use storage on the host, duplicating the same PVC over and over may lead to a quick lack of space left on the device
- CI/CD: probably a consequences coming from the previous points, however, managing several versions of an application (build/test/run ...) while using the same volume can improve TTM.

We will see an example with a Wordpress application, which is made of the following components:

- a _statefulset_ for the backend database, with its RWO PVC
- a _deployment_ for the Wordpress frontend also with its RWX PVC, as well as a _service_ used by the end user to connect to the application

## A. Wordpress deployment

Let's start by running this application.  

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario19_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password, and will push them to the local private registry:

Also, this scenario requires a LoadBalancer. If you have not installed one yet, you can refer to the MetalLB guide in [Addenda05](../../../Addendum/Addenda05). 

```bash
sh scenario19_pull_images.sh my_login my_password
```

I will use Helm to deploy Wordpress. All the variables are gathered in the _wordpress_values_rwx.yaml_:

```bash
kubectl create ns wp
helm install wp bitnami/wordpress --namespace wp -f wordpress_values_rwx.yaml
```

**OR** if you need local container images

```bash
helm install wp bitnami/wordpress --namespace wp -f wordpress_values_rwx.yaml --set global.imageRegistry=registry.demo.netapp.com
```

Here is a diagram of the result. As you can see, the frontend is composed of 2 POD mounting the same volume:

<p align="center"><img src="../Images/1_Wordpress_install.jpg"></p>

```bash
$ kubectl get -n wp deploy,rs,pod -l app.kubernetes.io/name=wordpress
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wp-wordpress   2/2     2            2           95m

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/wp-wordpress-58b4dfc8d   2         2         2       95m

NAME                               READY   STATUS    RESTARTS   AGE
pod/wp-wordpress-58b4dfc8d-cwwtc   1/1     Running   0          95m
pod/wp-wordpress-58b4dfc8d-xzcxd   1/1     Running   0          95m
```

Last, you can access this application through the external IP displayed by the following command (in my case 192.168.0.140):

```bash
$ kubectl get -n wp svc -l app.kubernetes.io/name=wordpress
NAME           TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
wp-wordpress   LoadBalancer   10.108.222.74   192.168.0.140   80:32491/TCP,443:32118/TCP   99m
```

## B. Scaling Wordpress

This weekend is a big day, and I need more frontend pods to absorb the incoming load. Let's scale it !

```bash
$ kubectl scale -n wp deploy wp-wordpress --replicas=3
deployment.apps/wp-wordpress scaled

$ kubectl get -n wp deploy,rs,pod -l app.kubernetes.io/name=wordpress
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wp-wordpress   3/3     3            3           97m

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/wp-wordpress-58b4dfc8d   3         3         3       97m

NAME                               READY   STATUS    RESTARTS   AGE
pod/wp-wordpress-58b4dfc8d-cwwtc   1/1     Running   0          97m
pod/wp-wordpress-58b4dfc8d-tcl84   1/1     Running   0          57s
pod/wp-wordpress-58b4dfc8d-xzcxd   1/1     Running   0          97m
```

Scaling this deployment was done non-disruptively, and the new pod mounts the very same PVC already present.

<p align="center"><img src="../Images/1_Wordpress_scale.jpg"></p>

## C. Upgrading Wordpress

A new version of Wordpress has been released, & I want to upgrade my environment non-disruptively. No problemo since we have a RWX NFS PVC!
Note that I use an image that I have already uploaded to the local repository. If you can directly pull the image from the docker hub, you can just remove the _registry.demo.netapp.com/_ part from the patch command.

```bash
$ kubectl patch -n wp deploy wp-wordpress -p '{"spec":{"template":{"spec":{"containers":[{"name":"wordpress","image":"registry.demo.netapp.com/bitnami/wordpress:5.8.2-debian-10-r12"}]}}}}'
deployment.apps/wp-wordpress patched

$ kubectl get -n wp deploy,rs,pod -l app.kubernetes.io/name=wordpress
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wp-wordpress   3/3     3            3           133m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/wp-wordpress-58b4dfc8d    0         0         0       133m
replicaset.apps/wp-wordpress-7fbd8f7d7b   3         3         3       2m7s

NAME                                READY   STATUS    RESTARTS   AGE
pod/wp-wordpress-7fbd8f7d7b-76tn4   1/1     Running   0          2m7s
pod/wp-wordpress-7fbd8f7d7b-dkd78   1/1     Running   0          91s
pod/wp-wordpress-7fbd8f7d7b-txdjf   1/1     Running   0          53s
```

<p align="center"><img src="../Images/1_Wordpress_upgrade.jpg"></p>

Once again, the process was done seamlessly. Even better, Kubernetes keeps the old ReplicaSet in case you need to rollback!

## D. Let's try to do the same with RWO

This time, the Helm variables are gathered in the _wordpress_values_rwo.yaml_:

```bash
kubectl create ns wprwo
helm install wp bitnami/wordpress --namespace wprwo -f wordpress_values_rwo.yaml
```

**OR** if you need local container images

```bash
kubectl create ns wprwo
helm install wp bitnami/wordpress --namespace wprwo -f wordpress_values_rwo.yaml --set global.imageRegistry=registry.demo.netapp.com
```

The resulting objects of a successful deployment are the following:

```bash
$ kubectl get -n wprwo deploy,sts,rs,pod,pvc
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wp-wordpress   1/1     1            1           4h47m

NAME                          READY   AGE
statefulset.apps/wp-mariadb   1/1     4h47m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/wp-wordpress-6bcfcf9445   1         1         1       4h47m

NAME                                READY   STATUS              RESTARTS   AGE
pod/wp-mariadb-0                    1/1     Running             0          4h46m
pod/wp-wordpress-6bcfcf9445-vqdvm   1/1     Running             0          4h46m

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/data-wp-mariadb-0   Bound    pvc-86704067-3ab3-4e58-b211-2747899d8249   8Gi        RWO            storage-class-nas   4h46m
persistentvolumeclaim/wp-wordpress        Bound    pvc-53f1b8ea-f5e6-48b2-b4b3-07ef910deef6   10Gi       RWO            storage-class-nas   4h47m
```

If we try to scale the frontend, it will fail:

```bash
$ kubectl scale -n wprwo deploy wp-wordpress --replicas=2
deployment.apps/wp-wordpress scaled

$ kubectl get -n wprwo deploy,rs,pod,pvc -l app.kubernetes.io/name=wordpress
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wp-wordpress   1/2     2            1           4h47m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/wp-wordpress-6bcfcf9445   2         2         1       4h47m

NAME                                READY   STATUS              RESTARTS   AGE
pod/wp-wordpress-6bcfcf9445-jtqdb   0/1     ContainerCreating   0          4m34s
pod/wp-wordpress-6bcfcf9445-vqdvm   1/1     Running             0          4h46m

NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/wp-wordpress        Bound    pvc-53f1b8ea-f5e6-48b2-b4b3-07ef910deef6   10Gi       RWO            storage-class-nas   4h47m

$ kubectl describe -n wprwo pod/wp-wordpress-6bcfcf9445-jtqdb | tail
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason              Age                    From                     Message
  ----     ------              ----                   ----                     -------
  Normal   Scheduled           <unknown>              default-scheduler        Successfully assigned wp/wp-wordpress-6bcfcf9445-jtqdb to rhel1
  Warning  FailedAttachVolume  9m49s                  attachdetach-controller  Multi-Attach error for volume "pvc-53f1b8ea-f5e6-48b2-b4b3-07ef910deef6" Volume is already used by pod(s) wp-wordpress-6bcfcf9445-vqdvm
  Warning  FailedMount         5m30s (x2 over 7m46s)  kubelet, rhel1           Unable to attach or mount volumes: unmounted volumes=[wordpress-data], unattached volumes=[default-token-sm5rt wordpress-data]: timed out waiting for the condition
  Warning  FailedMount         56s (x2 over 3m13s)    kubelet, rhel1           Unable to attach or mount volumes: unmounted volumes=[wordpress-data], unattached volumes=[wordpress-data default-token-sm5rt]: timed out waiting for the condition
```

This is normal, as a RWO volume can only be attached to one volume at one point in time.  
Let's scale back to one single POD:

```bash
$ kubectl scale -n wprwo deploy wp-wordpress --replicas=1
deployment.apps/wp-wordpress scaled
```

Now, what about upgrades ? It will fail for the very same reason!

```bash
$ kubectl patch -n wprwo deploy wp-wordpress -p '{"spec":{"template":{"spec":{"containers":[{"name":"wordpress","image":"registry.demo.netapp.com/bitnami/wordpress:5.8.2-debian-10-r12"}]}}}}'
deployment.apps/wp-wordpress patched

$ kubectl get -n wprwo deploy,rs,pod,pvc -l app.kubernetes.io/name=wordpress
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/wp-wordpress   1/1     1            1           4h59m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/wp-wordpress-6bcfcf9445   1         1         1       4h59m
replicaset.apps/wp-wordpress-756b45b7bf   1         1         0       57s

NAME                                READY   STATUS              RESTARTS   AGE
pod/wp-wordpress-6bcfcf9445-vqdvm   1/1     Running             0          4h59m
pod/wp-wordpress-756b45b7bf-hwzrc   0/1     ContainerCreating   0          57s

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/wp-wordpress   Bound    pvc-53f1b8ea-f5e6-48b2-b4b3-07ef910deef6   10Gi       RWO            storage-class-nas   4h59m

$ kubectl describe -n wprwo pod/wp-wordpress-756b45b7bf-hwzrc | tail
    Optional:    false
QoS Class:       Burstable
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason              Age        From                     Message
  ----     ------              ----       ----                     -------
  Normal   Scheduled           <unknown>  default-scheduler        Successfully assigned wp/wp-wordpress-756b45b7bf-hwzrc to rhel1
  Warning  FailedAttachVolume  73s        attachdetach-controller  Multi-Attach error for volume "pvc-53f1b8ea-f5e6-48b2-b4b3-07ef910deef6" Volume is already used by pod(s) wp-wordpress-6bcfcf9445-vqdvm
```

## E. Conclusion

Aside from the obvious "scalable distributed data" architecture that offers ReadWriteMany volumes, there are other benefits of using NFS that one cannot ignore. Not all applications can use shared data, however if it is built from the ground up to support the RWX model, you will gain on :

- space (on the host or attached storage)
- speed to scale (as data does not need to be copied & the container images may be smaller)
- ease of upgrade non disruptively
