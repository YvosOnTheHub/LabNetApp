#########################################################################################
# SCENARIO 3.1: Update Monitoring configuration
#########################################################################################

**GOAL:**  
We will here modify Grafana in order to use a persistent volumes to write its configuration.  
Then, we will install a _pie chart_ plugin that is used in one of the dashboards.

Let's first check the current status of the Prometheus Operator:

```bash
$ helm list -n monitoring
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
prom-operator   monitoring      2               2020-11-09 12:36:19.238070417 +0000 UTC deployed        prometheus-operator-9.3.1       0.38.1
```

<!-- OLD
In November 2020, the _stable_ Helm repository moved to a new URL: https://charts.helm.sh/stable.  
In order to install or update a new Helm chart, you will need to update the repository, which still points to the old URL: https://kubernetes-charts.storage.googleapis.com.  

```bash
helm repo add stable https://charts.helm.sh/stable
helm repo update
```
-->

## A. Clean up the environment

The Prometheus operator comes with a Grafana version that is pretty old. Using new dashboards may require features that do not exist in this environment.  
We will then first start by installing a much more recent Prometheus stack.  

But before, we need to clean up the existing environment:

```bash
helm uninstall -n monitoring prom-operator
kubectl delete ns monitoring
kubectl get crd -o name | grep monitoring | xargs kubectl delete
kubectl delete -n kube-system svc prom-operator-prometheus-o-kubelet
```

## B. Prometheus Stack installation

We can now proceed with the Prometheus stack installation with Helm.  
The PVC that will be created by Helm will use the _default_ storage class. Make sure you have one before moving on.  
If none is currently set to _default_, you can use the [Addenda02](../../Addendum/Addenda02) to help you create one.  

Note that the parameters used for this new installation are all in the _prometheus-stack-values_ yaml file passed as a variable with Helm.  
Take a look at its content & update it as you wish.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create ns monitoring
helm install prometheus-operator prometheus-community/kube-prometheus-stack -n monitoring --version 15.4.6 -f prometheus-stack-values.yaml
```

Once done you can see the result:

```bash
$ helm list -n monitoring
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
prometheus-operator     monitoring      1               2021-11-22 11:05:45.173079701 +0000 UTC deployed        kube-prometheus-stack-15.4.6    0.47.0

$ kubectl get -n monitoring svc,pod,pvc
NAME                                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/prometheus-operated                      ClusterIP   None             <none>        9090/TCP         149m
service/prometheus-operator-grafana              NodePort    10.102.230.219   <none>        80:30267/TCP     149m
service/prometheus-operator-kube-p-operator      ClusterIP   10.108.174.241   <none>        443/TCP          149m
service/prometheus-operator-kube-p-prometheus    NodePort    10.106.89.221    <none>        9090:32105/TCP   149m
service/prometheus-operator-kube-state-metrics   ClusterIP   10.100.84.121    <none>        8080/TCP         149m

NAME                                                         READY   STATUS    RESTARTS   AGE
pod/prometheus-operator-grafana-58947c859-ms5hh              2/2     Running   0          146m
pod/prometheus-operator-kube-p-operator-84f75f8bc9-ffr5w     1/1     Running   0          149m
pod/prometheus-operator-kube-state-metrics-957fc5f95-7w9r5   1/1     Running   0          149m
pod/prometheus-prometheus-operator-kube-p-prometheus-0       2/2     Running   1          146m

NAME                                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/prometheus-operator-grafana   Bound    pvc-535ed400-573e-4812-8aa4-a454573a47b1   10Gi       RWO            storage-class-nas   149m
```

## B. Install a Grafana plug-in

Grafana is a very powertul tool. You can install plenty of different plugins to create new neat dashboards.  
Let's see an example. I would like to install the **pie chart** model.This needs to be done directly in the _grafana_ container.  
This plugin is mandatory for the _debug dashboards_ that you will use in a few minutes.  

```bash
$ kubectl exec -n monitoring -it $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name) -c grafana -- grafana-cli plugins install grafana-piechart-panel
installing grafana-piechart-panel @ 1.6.1
from: https://grafana.com/api/plugins/grafana-piechart-panel/versions/1.6.1/download
into: /var/lib/grafana/plugins

✔ Installed grafana-piechart-panel successfully

Restart grafana after installing plugins . <service grafana-server restart>
```

As stated, you need to restart the grafana service in order to take into account the model.
There are many ways to restart a pod which is part of a deployment. One can decide to scale down the deployment to 0, wait a few seconds & then scale up back to 1.

```bash
$ kubectl scale -n monitoring deploy -l app.kubernetes.io/name=grafana --replicas=0
deployment.extensions/prom-operator-grafana scaled

$ kubectl scale -n monitoring deploy -l app.kubernetes.io/name=grafana --replicas=1
deployment.extensions/prom-operator-grafana scaled
```

Let's check if it has been well installed

```bash
$ kubectl exec -n monitoring -it $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name) -c grafana -- grafana-cli plugins ls
installed plugins:
grafana-piechart-panel @ 1.6.1

Restart grafana after installing plugins . <service grafana-server restart>
```

When you create a new dashboard, you will now have access to a new format:  
<p align="center"><img src="../Images/pie_chart.jpg"></p>

## C. What's next

Let's see how to use [Prometheus](../2_Prometheus).
