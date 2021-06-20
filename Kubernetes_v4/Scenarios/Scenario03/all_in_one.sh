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
echo "Installing the Prometheus Operator with Helm"
echo "#######################################################################################################"
#
# Depending on your needs, you can continue with the operator from the "stable" chart, which is deprecated, or move to the newer model
# => PROM = DEPRECATED (default) or UPDATE
PROM="DEPRECATED"

if [[ $PROM == "DEPRECATED" ]];then
  helm upgrade prom-operator stable/prometheus-operator --namespace monitoring --set prometheusOperator.createCustomResource=false,grafana.persistence.enabled=true
elif [[ $PROM == "UPDATE" ]];then
  helm uninstall -n monitoring prom-operator
  kubectl delete ns monitoring
  kubectl get crd -o name | grep monitoring | xargs kubectl delete
  
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update

  kubectl create ns monitoring
  helm install prometheus-operator prometheus-community/kube-prometheus-stack -n monitoring --version 15.4.6 --set grafana.persistence.enabled=true,grafana.service.type=NodePort,prometheus.service.type=NodePort
fi

while [ $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name | wc -l) -ne 1 ]
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

echo "#######################################################################################################"
echo "Create ConfigMap for Dashboards"
echo "#######################################################################################################"

kubectl create configmap -n monitoring cm-trident-dashboard --from-file=3_Grafana/Dashboards/
kubectl label configmap -n monitoring cm-trident-dashboard grafana_dashboard=1

PROMVERSION=$(helm list -n monitoring | tail -1 | awk '{print $1}')
if [[ $PROMVERSION == "prometheus-operator" ]];then
  echo "#######################################################################################################"
  echo "Update Trident Service Monitor for Prometheus"
  echo "#######################################################################################################"
  kubectl label -n monitoring servicemonitor trident-sm release=prometheus-operator --overwrite
fi