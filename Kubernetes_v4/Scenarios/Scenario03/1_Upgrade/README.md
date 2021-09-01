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

In November 2020, the _stable_ Helm repository moved to a new URL: https://charts.helm.sh/stable.  
In order to install or update a new Helm chart, you will need to update the repository, which still points to the old URL: https://kubernetes-charts.storage.googleapis.com.  

```bash
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

## A. Modify the Prometheus configuration

The PVC that will be created by Helm will use the _default_ storage class. Make sure you have one before moving on.  
If none is currently set to _default_, you can use the [Addenda02](../../Addendum/Addenda02) to help you create one.  

Let's proceed with the upgrade:

```bash
$ helm upgrade prom-operator stable/prometheus-operator --namespace monitoring --set prometheusOperator.createCustomResource=false,grafana.persistence.enabled=true
```

If you now check the volumes attached to this namespace, you will see a new one:

```bash
$ kubectl get pvc,pv -n monitoring
NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/prom-operator-grafana   Bound    pvc-7fe5ff86-c80f-4553-a09f-b26a7675a5cd   10Gi       RWO            storage-class-nas   154m

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                              STORAGECLASS        REASON   AGE
persistentvolume/pvc-7fe5ff86-c80f-4553-a09f-b26a7675a5cd   10Gi       RWO            Delete           Bound    monitoring/prom-operator-grafana   storage-class-nas            154m
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
