#!/bin/bash

# OPTIONAL PARAMETERS: 
# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario03

if [[ $(yum info jq -y 2> /dev/null | grep Repo | awk '{ print $3 }') != "installed" ]]; then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi

if [[  $(docker images | grep registry | grep grafana | grep 9.1.4 | wc -l) -eq 0 ]]; then
  if [ $# -eq 2 ]; then
    sh scenario03_pull_images.sh $1 $2  
  else
    TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
    RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

    if [[ $RATEREMAINING -lt 20 ]];then
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have many pull requests left ($RATEREMAINING). Consider using your own credentials"
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
    else
      sh scenario03_pull_images.sh
    fi
  fi
fi


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
helm upgrade -f 1_Upgrade/prometheus-stack-values.yaml prometheus prometheus-community/kube-prometheus-stack -n monitoring --version 39.13.3

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
