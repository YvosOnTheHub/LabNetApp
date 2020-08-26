#########################################################################################
# SCENARIO 2: Install Prometheus & integrate Trident's metrics
#########################################################################################

**GOAL:**  
Trident 20.01.1 introduced metrics that can be integrated into Prometheus.  
Going through this scenario at this point will be interesting as you will actually see the metrics evolve with all the labs.  

You can either follow this scenario or go through the following link:  
https://netapp.io/2020/02/20/a-primer-on-prometheus-trident/

## A. Install Helm

Helm, as a packaging tool, will be used to install Prometheus.

```bash
cd
wget https://get.helm.sh/helm-v3.0.3-linux-amd64.tar.gz
tar xzvf helm-v3.0.3-linux-amd64.tar.gz
cp linux-amd64/helm /usr/bin/
```

## B. Install Prometheus in its own namespace

```bash
kubectl create namespace monitoring
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm install prom-operator stable/prometheus-operator  --namespace monitoring
```

You can check the installation with the following command:

```bash
$ helm list -n monitoring
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
prom-operator   monitoring      1               2020-04-30 12:43:12.515947662 +0000 UTC deployed        prometheus-operator-8.13.4      0.38.1
```

## C. Expose Prometheus

Prometheus got installed pretty easily.
But how can you access from your browser?

The way Prometheus is installed (service of _ClusterIP_ type) requires it to be access from the host where it is installed (with a *port-forwarding* mechanism for instance).

```bash
$ kubectl get -n monitoring svc -l app=prometheus-operator-prometheus
NAME                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
prom-operator-prometheus-o-prometheus   ClusterIP   10.110.162.207   <none>        9090/TCP   3m15s
```

We will modify the Prometheus service in order to access it from anywhere in the lab.  
You could choose the *NodePort* method or the *LoadBalancer* one as you prefer.  
To keep it simple, I will use the *LoadBalancer* method. Please refer to the [Addenda07](../../Addendum/Addenda07) which explains how to install & configure MetalLB.  

2 parameters of the Prometheus service need to be modified. You can either edit it or patch it, solution I chose here:

```bash
$ kubectl patch -n monitoring svc prom-operator-prometheus-o-prometheus -p '{"spec":{"type":"LoadBalancer"}}'
service/prom-operator-prometheus-o-prometheus patched

$ kubectl patch -n monitoring svc prom-operator-prometheus-o-prometheus --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value":80}]'
service/prom-operator-prometheus-o-prometheus patched

$ kubectl get -n monitoring svc -l app=prometheus-operator-prometheus
NAME                                    TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
prom-operator-prometheus-o-prometheus   LoadBalancer   10.110.162.207   192.168.0.140   80:30446/TCP   30m
```

You can now access the Prometheus GUI from the browser using the IP address 192.168.0.140.  

## D. Add Trident to Prometheus

Refer to the blog aforementioned to get the details about how this Service Monitor works.
The following link is also a good place to find information:
https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md

In substance, we will tell in this object to look at services that have the label *trident* & retrieve metrics from its endpoint.
The Yaml file has been provided and is available in the Scenario2 sub-directory

```bash
$ kubectl create -f LabNetApp/Kubernetes_v2/Scenarios/Scenario02/Trident_ServiceMonitor.yml
servicemonitor.monitoring.coreos.com/trident-sm created
```

## E. Check the configuration

On the browser in the LoD, you can now connect to the address http://192.168.0.140 in order to access Prometheus
You can check that the Trident endpoint is taken into account & in the right state by going to the menu STATUS => TARGETS

![Trident Status in Prometheus](Images/Trident_status_in_prometheus.jpg "Trident Status in Prometheus")

## F. Play around

Now that Trident is integrated into Prometheus, you can retrieve metrics or build graphs.

## G. What's next

Now that Trident is connected to Prometheus, you can proceed with :

- [Scenario03](../Scenario03):  Configure Grafana & add your first graphs  

or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)