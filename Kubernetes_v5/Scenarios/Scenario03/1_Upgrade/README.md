#########################################################################################
# SCENARIO 3.1: Update Monitoring configuration
#########################################################################################

**GOAL:**  
We will here modify Grafana in order to use a persistent volumes to write its configuration.  
That could become useful if you wanted to play around with dashboards & data, which will then be saved on this volume.  
We will also remove some unused Prometheus elements, just to save some resources.  

Let's first check the current status of the Prometheus Operator:

```bash
$ helm ls -n monitoring
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
prometheus      monitoring      1               2022-01-14 02:09:45.542413997 +0000 UTC deployed        kube-prometheus-stack-23.1.2    0.52.0
```

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this scenario root directory _scenario03_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 **optional** parameters, your Docker Hub login & password:

```bash
sh scenario03_pull_images.sh my_login my_password
```

We can now proceed with the Prometheus stack upgrade with Helm.  
The PVC that will be created by Helm will use the _default_ storage class. Make sure you have one before moving on.  
If none is currently set to _default_, you can use the [Addenda02](../../Addendum/Addenda02) to help you create one.  

Note that the parameters used for this new installation are all in the _prometheus-stack-values.yaml_ file passed as a variable with Helm.  
Take a look at its content & update it as you wish.

```bash
helm upgrade -f prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack -n monitoring --version 39.13.3
```

Once done you can see the result:

```bash
$ helm list -n monitoring
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                            APP VERSION
prometheus-operator     monitoring      1               2022-11-21 11:05:45.173079701 +0000 UTC deployed        kube-prometheus-stack-39.13.3    0.58.0

$ kubectl get -n monitoring svc,pod,pvc
NAME                                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/prometheus-grafana                      NodePort    10.102.82.198    <none>        80:30267/TCP     194d
service/prometheus-kube-prometheus-operator     ClusterIP   10.100.221.31    <none>        443/TCP          45s
service/prometheus-kube-prometheus-prometheus   NodePort    10.110.219.127   <none>        9090:32105/TCP   45s
service/prometheus-kube-state-metrics           ClusterIP   10.106.42.121    <none>        8080/TCP         194d
service/prometheus-operated                     ClusterIP   None             <none>        9090/TCP         194d

NAME                                                       READY   STATUS    RESTARTS   AGE
pod/prometheus-grafana-757bc494bb-jhjgw                    3/3     Running   0          45s
pod/prometheus-kube-prometheus-operator-5845dd74f4-gn5dw   1/1     Running   0          45s
pod/prometheus-kube-state-metrics-6d69f48455-gkxqh         1/1     Running   0          45s
pod/prometheus-prometheus-kube-prometheus-prometheus-0     2/2     Running   0          35s

NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/prometheus-grafana   Bound    pvc-e8418388-eff9-4fbe-8021-ce5c57898985   10Gi       RWO            storage-class-nas   46s
```

There you go, a freshly updated Prometheus stack !

## C. What's next

Let's see how to use [Prometheus](../2_Prometheus).
