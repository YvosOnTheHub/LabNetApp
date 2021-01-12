#!/bin/bash

cd ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario03

if [ $(kubectl get sc | grep "(default)" | wc -l) = 0 ]
  then
    echo "#######################################################################################################"
    echo "Assign a default storage class"
    echo "#######################################################################################################"

    kubectl patch storageclass storage-class-nas -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

echo "#######################################################################################################"
echo "Update Helm stable repo"
echo "#######################################################################################################"
helm repo add stable https://charts.helm.sh/stable
helm repo update

echo "#######################################################################################################"
echo "Upgrade Prometheus Operator with Helm"
echo "#######################################################################################################"
helm upgrade prom-operator stable/prometheus-operator --namespace monitoring --set prometheusOperator.createCustomResource=false,grafana.persistence.enabled=true

while [ $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --field-selector=status.phase=Running --output=name | wc -l) -ne 1 ]
do
  echo "sleep a bit ..."
  sleep 5
done

echo "#######################################################################################################"
echo "Install Pie Chart Plugin in Grafana"
echo "#######################################################################################################"

kubectl exec -n monitoring -it $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name) -c grafana -- grafana-cli plugins install grafana-piechart-panel
kubectl scale -n monitoring deploy prom-operator-grafana --replicas=0
while [ $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name | wc -l) -ne 0 ]
do
  echo "sleep a bit ..."
  sleep 5
done
kubectl scale -n monitoring deploy prom-operator-grafana --replicas=1
sleep 15s

echo "#######################################################################################################"
echo "Create ConfigMap for Dashboards"
echo "#######################################################################################################"

kubectl create configmap -n monitoring cm-trident-dashboard --from-file=3_Grafana/Dashboards/
kubectl label configmap -n monitoring cm-trident-dashboard grafana_dashboard=1