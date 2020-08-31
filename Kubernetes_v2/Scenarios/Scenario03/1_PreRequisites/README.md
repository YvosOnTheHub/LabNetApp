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
wget https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz
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
$ kubectl create -f LabNetApp/Kubernetes_v2/Scenarios/Scenario03/1_PreRequisites/cm-grafana-datasources.yaml
configmap/cm-grafana-datasources created
```

## D. Network

For this scenario, we are going to use a LoadBalancer to automatically assign IP addresses to both Prometheus & Grafana services.  
Please refer to the [Addenda07](LabNetApp/Kubernetes_v2/Addendum/Addenda07) which explains how to install & configure MetalLB.

## E. Storage

We are going to use a Persistent Volume to store Grafana's data.  That way if the pod fails, you are not going to lose its configuration.

## F. What's next

Time to [install Prometheus](../2_Prometheus)!  
