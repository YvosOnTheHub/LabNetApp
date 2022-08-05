#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/Loft_vClusters/Ghost_vc2

kubectl --kubeconfig ~/kubeconfig_vc2 create ns ghostvc2

kubectl --kubeconfig ~/kubeconfig_vc2 create -n ghostvc2 -f 1-ghost_vc2-pvc.yaml
kubectl --kubeconfig ~/kubeconfig_vc2 create -n ghostvc2 -f 2-ghost_vc2-svc.yaml

sleep 5s
VC2_GHOST_SERVICE_IP=$(kubectl --kubeconfig ~/kubeconfig_vc2 get -n ghostvc2 svc blog-vc2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i s,GHOST_SERVICE_IP,$VC2_GHOST_SERVICE_IP, 3-ghost_vc2-deploy.yaml

kubectl --kubeconfig ~/kubeconfig_vc2 create -n ghostvc2 -f 3-ghost_vc2-deploy.yaml