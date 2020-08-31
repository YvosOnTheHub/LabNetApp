#########################################################################################
# SCENARIO 3: Prerequisites
#########################################################################################

**GOAL:**  
Install all the tools & objects that will be used by Prometheus & Grafana:
- Install Helm
- Create namespace
- Create a ConfigMap for the Grafana datasource

The datasource configmap must be present before the installation, as Grafana will scan existing objects in order to complete its setup.

## A. Install Helm

Helm, as a packaging tool, will be used to install Prometheus.

```bash
cd
wget https://get.helm.sh/helm-v3.0.3-linux-amd64.tar.gz
tar xzvf helm-v3.3.0-linux-amd64.tar.gz
cp linux-amd64/helm /usr/bin/
helm repo add stable https://kubernetes-charts.storage.googleapis.com
```

## B. Monitoring namespace

We will install Prometheus & Grafana in one namespace called _monitoring_.  

```bash
$ kubectl create namespace monitoring
```

## C. Create a configmap for the datasource

:mag:  
*A* **ConfigMap** *is an API object used to store non-confidential data in key-value pairs.  
Pods can consume ConfigMaps as environment variables, command-line arguments, or as configuration files in a volume. A ConfigMap allows you to decouple environment-specific configuration from your container images, so that your applications are easily portable.*  
:mag_right: 

If the parameter _sidecar.datasources.enabled_ is set, an init container is deployed in the grafana pod.  
This container lists all secrets or configmaps in the cluster and filters out the ones with a label as defined in _sidecar.datasources.label_ (default **grafana_datasource**).  
The files defined in those objects are written to a folder and accessed by grafana on startup. Using these yaml files, the data sources in grafana can be imported.  
The configmap must be created before helm install so that the datasources init container can list the configmap.

```bash
$ kubectl create -f LabNetApp/Kubernetes_v2/Scenarios/Scenario03/1_PreRequisites/cm-grafana_datasource.yaml
```

## D. Network

For this scenario, we are going to use a LoadBalancer to automatically assign IP addresses to both Prometheus & Grafana services.  
Please refer to the [Addenda07](../../../Addendum/Addenda07) which explains how to install & configure MetalLB.

## E. Storage

We are going to use a Persistent Volume to store Grafana's data.  That way if the pod fails, you are not going to lose its configuration.

## F. What's next

Time to [install Prometheus](../2_Prometheus)!










You can either follow this scenario or go through the following link:  
https://netapp.io/2020/02/20/a-primer-on-prometheus-trident/

## A. Install Helm

Helm, as a packaging tool, will be used to install Prometheus.

```bash
cd
wget https://get.helm.sh/helm-v3.0.3-linux-amd64.tar.gz
tar xzvf helm-v3.0.3-linux-amd64.tar.gz
cp linux-amd64/helm /usr/bin/
helm repo add stable https://kubernetes-charts.storage.googleapis.com
```

## B. Install Prometheus in its own namespace

Due to a bug in Helm, you first need to manually create some CRD.  
For more information about this, take a look at https://github.com/helm/charts/tree/master/stable/prometheus-operator#helm-fails-to-create-crds.  

```bash
# WITH KUBERNETES < v1.16
kubectl create -f CRD/monitoring.coreos.com_alertmanagers.yaml
kubectl create -f CRD/monitoring.coreos.com_podmonitors.yaml
kubectl create -f CRD/monitoring.coreos.com_prometheuses.yaml
kubectl create -f CRD/monitoring.coreos.com_prometheusrules.yaml
kubectl create -f CRD/monitoring.coreos.com_servicemonitors.yaml
kubectl create -f CRD/monitoring.coreos.com_thanosrulers.yaml

# WITH KUBERNETES >= v1.16
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
```

```bash
kubectl create namespace monitoring
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

## G. Optional cleanup

If you want to delete this chart, you can use the following commands:

```bash
$ helm delete prom-operator -n monitoring
release "prom-operator" uninstalled
```

Also, this process does not clean up the CRD, nor the namespace. You can use the following commands to complete the cleanup

```bash
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com
kubectl delete namespace monitoring
```

## H. What's next

Now that Trident is connected to Prometheus, you can proceed with :

- [Scenario03](../Scenario03):  Configure Grafana & add your first graphs  

or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)