#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario03

if [ $(kubectl get sc | grep "(default)" | wc -l) = 0 ]
  then
    echo "#######################################################################################################"
    echo "Assign a default storage class"
    echo "#######################################################################################################"

    kubectl patch storageclass storage-class-nas -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

echo "#######################################################################################################"
echo "Upgrading the Prometheus Operator"
echo "#######################################################################################################"

# DOC: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
helm repo update
helm upgrade -f 1_Upgrade/prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack -n monitoring

frames="/ | \\ -"
while [ $(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the Grafana POD to exist $frame" 
    done
done
echo

PODNAME=$(kubectl get -n monitoring pod -l app.kubernetes.io/name=grafana --output=name)
until [[ $(kubectl -n monitoring get $PODNAME -o=jsonpath='{.status.conditions[?(@.type=="ContainersReady")].status}') == 'True' ]]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the Grafana POD to be fully ready $frame" 
    done
done

echo "#######################################################################################################"
echo "Create ConfigMap for Dashboards"
echo "#######################################################################################################"

kubectl create configmap -n monitoring cm-trident-dashboard --from-file=3_Grafana/Dashboards/
kubectl label configmap -n monitoring cm-trident-dashboard grafana_dashboard=1
