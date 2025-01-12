#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario21/Loft_vClusters/Ghost_vc1

kubectl --kubeconfig ~/kubeconfig_vc1 create ns ghostvc1

kubectl --kubeconfig ~/kubeconfig_vc1 create -n ghostvc1 -f 1-ghost_vc1-pvc.yaml
kubectl --kubeconfig ~/kubeconfig_vc1 create -n ghostvc1 -f 2-ghost_vc1-svc.yaml

sleep 5s
VC1_GHOST_SERVICE_IP=$(kubectl --kubeconfig ~/kubeconfig_vc1 get -n ghostvc1 svc blog-vc1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i s,GHOST_SERVICE_IP,$VC1_GHOST_SERVICE_IP, 3-ghost_vc1-deploy.yaml

kubectl --kubeconfig ~/kubeconfig_vc1 create -n ghostvc1 -f 3-ghost_vc1-deploy.yaml