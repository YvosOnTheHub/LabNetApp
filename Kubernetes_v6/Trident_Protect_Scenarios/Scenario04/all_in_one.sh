echo
echo "############################################"
echo "### Install Kube State Metrics"
echo "############################################"
helm repo update prometheus-community
helm install trident-protect prometheus-community/kube-state-metrics --version 5.21.0 -n monitoring -f ksm-values.yaml

echo
echo "############################################"
echo "### Add a Grafana dashboard"
echo "############################################"
kubectl create configmap -n monitoring cm-trident-protect-dashboard --from-file=dashboard.json
kubectl label configmap -n monitoring cm-trident-protect-dashboard grafana_dashboard=1