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
```
# cd
# wget https://get.helm.sh/helm-v3.0.3-linux-amd64.tar.gz
# tar xzvf helm-v3.0.3-linux-amd64.tar.gz
# cp linux-amd64/helm /usr/bin/
```

## B. Install Prometheus in its own namespace
```
# kubectl create namespace monitoring
# helm repo add stable https://kubernetes-charts.storage.googleapis.com
# helm install prom-operator stable/prometheus-operator  --namespace monitoring
```
You can check the installation with the following command:
```
# helm list -n monitoring
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
prom-operator   monitoring      1               2020-04-30 12:43:12.515947662 +0000 UTC deployed        prometheus-operator-8.13.4      0.38.1
```

## C. Expose Prometheus

Prometheus got installed pretty easily.
But how can you access from your browser?

The way Prometheus is installed required it to be access from the host where it is installed (with a *port-forwarding* mechanism for instance).
We will modify the Prometheus service in order to access it from anywhere in the lab, with why not a *NodePort* configuration
```
# kubectl edit -n monitoring svc prom-operator-prometheus-o-prometheus
```

### BEFORE:
```
spec:
  clusterIP: 10.96.69.69
  ports:
  - name: web
    port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    app: prometheus
    prometheus: prom-operator-prometheus-o-prometheus
  sessionAffinity: None
  type: ClusterIP
```

### AFTER: (look at the ***nodePort*** & ***type*** lines)
```
spec:
  clusterIP: 10.96.69.69
  ports:
  - name: web
    port: 9090
    nodePort: 30000
    protocol: TCP
    targetPort: 9090
  selector:
    app: prometheus
    prometheus: prom-operator-prometheus-o-prometheus
  sessionAffinity: None
  type: NodePort
```

You can now access the Prometheus GUI from the browser using the port 30000 on RHEL3 address (http://192.168.0.63:30000)

## D. Add Trident to Prometheus

Refer to the blog aforementioned to get the details about how this Service Monitor works.
The following link is also a good place to find information:
https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/getting-started.md

In substance, we will tell in this object to look at services that have the label *trident* & retrieve metrics from its endpoint.
The Yaml file has been provided and is available in the Scenario2 sub-directory

```
# kubectl create -f LabNetApp/Kubernetes_v2/Scenarios/Scenario02/Trident_ServiceMonitor.yml
servicemonitor.monitoring.coreos.com/trident-sm created
```

## E. Check the configuration

On the browser in the LoD, you can now connect to the address http://192.168.0.63:30000 in order to access Prometheus
You can check that the Trident endpoint is taken into account & in the right state by going to the menu STATUS => TARGETS

![Trident Status in Prometheus](Images/Trident_status_in_prometheus.jpg "Trident Status in Prometheus")

## F. Play around

Now that Trident is integrated into Prometheus, you can retrieve metrics or build graphs.


## G. What's next

Now that Trident is connected to Prometheus, you can proceed with :  
- [Scenario03](../Scenario03):  Configure Grafana & add your first graphs  

or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)