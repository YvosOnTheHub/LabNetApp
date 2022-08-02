#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/Ghost_vc1

kubectl --kubeconfig ~/kubeconfig_vc1.yaml create ns ghostvc1

kubectl --kubeconfig ~/kubeconfig_vc1.yaml create -n ghostvc1 -f 1-ghost_vc1-pvc.yaml
kubectl --kubeconfig ~/kubeconfig_vc1.yaml create -n ghostvc1 -f 2-ghost_vc1-svc.yaml

VC1_GHOST_SERVICE_IP=$(kubectl --kubeconfig ~/kubeconfig_vc1.yaml get -n ghostvc1 svc blog-vc1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i s,GHOST_SERVICE_IP,$VC1_GHOST_SERVICE_IP, 3-ghost_vc1-deploy.yaml

kubectl --kubeconfig ~/kubeconfig_vc1.yaml create -n ghostvc1 -f 3-ghost_vc1-deploy.yaml