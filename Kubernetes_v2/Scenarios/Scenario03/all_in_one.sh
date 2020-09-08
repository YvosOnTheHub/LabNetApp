#!/bin/bash

echo "#######################################################################################################"
echo "Install Helm"
echo "#######################################################################################################"

cd
wget https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz
tar xzvf helm-v3.3.0-linux-amd64.tar.gz
cp linux-amd64/helm /usr/bin/
helm repo add stable https://kubernetes-charts.storage.googleapis.com

echo "#######################################################################################################"
echo "Create Monitoring Namespace"
echo "#######################################################################################################"

kubectl create namespace monitoring

echo "#######################################################################################################"
echo "Create ConfigMap for DataSources"
echo "#######################################################################################################"

cd LabNetApp/Kubernetes_v2/Scenarios/Scenario03
kubectl create -f 1_PreRequisites/cm-grafana-datasources.yaml

echo "#######################################################################################################"
echo "Creating Prometheus CRD"
echo "#######################################################################################################"

if [[ $(kubectl version | grep -e Server | awk -F ',' '{print $2}' | awk '{print substr($0, 9, 2)}') > "15" ]]
then
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
  kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
fi

echo "#######################################################################################################"
echo "Install Prometheus Operator with Helm"
echo "#######################################################################################################"

if [[ $(kubectl version | grep -e Server | awk -F ',' '{print $2}' | awk '{print substr($0, 9, 2)}') = "15" ]]
then
  helm install prom-operator stable/prometheus-operator --namespace monitoring --set grafana.persistence.enabled=true,grafana.sidecar.datasources.defaultDatasourceEnabled=false
else
  helm install prom-operator stable/prometheus-operator --namespace monitoring --set prometheusOperator.createCustomResource=false,grafana.persistence.enabled=true,grafana.sidecar.datasources.defaultDatasourceEnabled=false
fi

echo "#######################################################################################################"
echo "Patch Prometheus & Grafana services to run with LoadBalancer"
echo "#######################################################################################################"

kubectl patch -n monitoring svc prom-operator-prometheus-o-prometheus -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch -n monitoring svc prom-operator-prometheus-o-prometheus --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value":80}]'
kubectl patch -n monitoring svc prom-operator-grafana  -p '{"spec":{"type":"LoadBalancer"}}'

echo "#######################################################################################################"
echo "Create Trident Service Monitor"
echo "#######################################################################################################"

kubectl create -f 2_Prometheus/Trident_ServiceMonitor.yml

echo "#######################################################################################################"
echo "Install Pie Chart Plugin in Grafana"
echo "#######################################################################################################"

kubectl exec -n monitoring -it $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name) -c grafana -- grafana-cli plugins install grafana-piechart-panel
kubectl scale -n monitoring deploy prom-operator-grafana --replicas=0
kubectl scale -n monitoring deploy prom-operator-grafana --replicas=1

echo "#######################################################################################################"
echo "Create ConfigMap for Dashboards"
echo "#######################################################################################################"

kubectl create configmap -n monitoring cm-trident-dashboard --from-file=3_Grafana/Dashboards/Trident_Dashboard_Std.json
kubectl label configmap -n monitoring cm-trident-dashboard grafana_dashboard=1