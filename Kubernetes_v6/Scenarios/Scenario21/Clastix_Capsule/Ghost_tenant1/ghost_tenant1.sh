#!/bin/bash

cd ~/LabNetApp/Kubernetes_v6/Scenarios/Scenario21/Clastix_Capsule/Ghost_tenant1

kubectl --kubeconfig ../owner1-tenant1.kubeconfig create ns tenant1-ghost

kubectl --kubeconfig ../owner1-tenant1.kubeconfig create -n tenant1-ghost -f 1-ghost_tenant1-pvc.yaml
kubectl --kubeconfig ../owner1-tenant1.kubeconfig create -n tenant1-ghost -f 2-ghost_tenant1-svc.yaml

sleep 5s
TENANT1_GHOST_SERVICE_IP=$(kubectl --kubeconfig ../owner1-tenant1.kubeconfig get -n tenant1-ghost svc blog-tenant1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i s,GHOST_SERVICE_IP,$TENANT1_GHOST_SERVICE_IP, 3-ghost_tenant1-deploy.yaml

kubectl --kubeconfig ../owner1-tenant1.kubeconfig create -n tenant1-ghost -f 3-ghost_tenant1-deploy.yaml