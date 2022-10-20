cd
git clone https://github.com/YvosOnTheHub/LabNetApp.git

mkdir demo_capsule && cd demo_capsule
mkdir YAML

cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/scenario21_trident_config.yaml  YAML/demo_trident_config.yaml
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/scenario21_storage_classes.yaml YAML/demo_storage_classes.yaml
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario13/sc-volumesnapshot.yaml YAML/demo_snapshot_class.yaml
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/Clastix_Capsule/tenant* YAML/
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/Clastix_Capsule/clusterrole_volumesnapshots.yaml YAML/
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/Clastix_Capsule/create-user.sh .

sed -i 's/sc21/demo/' YAML/demo_trident_config.yaml
sed -i '41s/135/220/' YAML/demo_trident_config.yaml
sed -i '48s/false/true/' YAML/demo_trident_config.yaml
sed -i 's/aggr2/aggr1/' YAML/demo_storage_classes.yaml

mkdir Tenant1_Ghost1
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/Clastix_Capsule/Ghost_tenant1/* Tenant1_Ghost1/
sed -i 's/sc21/demo/' Tenant1_Ghost1/1-ghost_tenant1-pvc.yaml
sed -i 's/sc21/demo/' Tenant1_Ghost1/2-ghost_tenant1-svc.yaml
sed -i 's/sc21/demo/' Tenant1_Ghost1/3-ghost_tenant1-deploy.yaml
rm -f Tenant1_Ghost1/ghost_tenant1.sh

mkdir Tenant1_Ghost2
cp Tenant1_Ghost1/* Tenant1_Ghost2/
mv Tenant1_Ghost2/1-ghost_tenant1-pvc.yaml Tenant1_Ghost2/1-ghost2_tenant1-pvc.yaml
mv Tenant1_Ghost2/2-ghost_tenant1-svc.yaml Tenant1_Ghost2/2-ghost2_tenant1-svc.yaml
mv Tenant1_Ghost2/3-ghost_tenant1-deploy.yaml Tenant1_Ghost2/3-ghost2_tenant1-deploy.yaml
sed -i 's/demo/demo2/' Tenant1_Ghost2/1-ghost2_tenant1-pvc.yaml
sed -i 's/demo/demo2/' Tenant1_Ghost2/2-ghost2_tenant1-svc.yaml
sed -i 's/demo_/demo2_/' Tenant1_Ghost2/3-ghost2_tenant1-deploy.yaml
sed -i 's/blog/blog2/' Tenant1_Ghost2/1-ghost2_tenant1-pvc.yaml
sed -i 's/blog/blog2/' Tenant1_Ghost2/2-ghost2_tenant1-svc.yaml
sed -i 's/blog/blog2/' Tenant1_Ghost2/3-ghost2_tenant1-deploy.yaml

mkdir Tenant2_Busybox
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario09/1_File_PVC/pvc.yaml Tenant2_Busybox/
cp /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario09/1_File_PVC/pod-busybox-nas.yaml Tenant2_Busybox/
sed -i 's/storage-class-nas/sc-tenant2/' Tenant2_Busybox/pvc.yaml
sed -i 's/pvc-to-resize-file/bboxpvc/' Tenant2_Busybox/pvc.yaml
sed -i 's/pvc-to-resize-file/bboxpvc/' Tenant2_Busybox/pod-busybox-nas.yaml

kubectl create -f YAML/demo_snapshot_class.yaml

kubectl label node rhel1 "tenant1=true"
kubectl label node rhel2 "tenant1=true"
kubectl label node rhel2 "tenant2=true"
kubectl label node rhel3 "tenant2=true"

sh /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario01/scenario01_pull_images.sh tsupd0ck jcgrup5D
sh /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario09/scenario09_pull_images.sh tsupd0ck jcgrup5D
sh /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario21/scenario21_pull_images.sh tsupd0ck jcgrup5D
sh /root/LabNetApp/Kubernetes_v5/Scenarios/Scenario01/2_Helm/trident_uninstall.sh
sh /root/LabNetApp/Kubernetes_v5/Addendum/Addenda05/all_in_one.sh tsupd0ck jcgrup5D
sh /root/LabNetApp/Kubernetes_v5/Addendum/Addenda01/add_node.sh rhel4

kubectl apply -f https://raw.githubusercontent.com/clastix/capsule/v0.1.1/config/install.yaml
sleep 2
kubectl apply -f https://raw.githubusercontent.com/clastix/capsule/v0.1.1/config/install.yaml
kubectl patch capsuleconfigurations.capsule.clastix.io capsule-default --type=merge -p '{"spec": {"forceTenantPrefix": true}}'





cat > 1_trident_install.sh << EOF
echo "#######################################################################################################"
echo "Install new Trident Operator (22.07.0) with Helm"
echo "#######################################################################################################"
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm repo update
sleep 5s
helm install trident netapp-trident/trident-operator --version 22.7.0 -n trident --create-namespace --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:22.07.0,operatorImage=registry.demo.netapp.com/trident-operator:22.07.0,tridentImage=registry.demo.netapp.com/trident:22.07.0

frames="/ | \\ -"
while [ \$(kubectl get -n trident pod | grep Running | wc -l) -ne 5 ]; do
    for frame in \$frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready \$frame"
    done
done

echo
sleep 10s

kubectl get pod -n trident
kubectl get tver -n trident
EOF





cat > 2_trident_configure.sh << EOF
echo "#######################################################################################################"
echo " Configure Trident and Create Storage Classes"
echo "#######################################################################################################"
kubectl create -n trident -f YAML/demo_trident_config.yaml
kubectl create -f YAML/demo_storage_classes.yaml

sleep 5s
echo "#######################################################################################################"
echo " We now have 2 Trident backends and 2 storage classes"
echo "#######################################################################################################"
kubectl -n trident get tbc
kubectl get sc
EOF




cat > 3_create_tenants.sh << EOF
echo "#######################################################################################################"
echo " Let's Create 2 Capsule Tenants and Create kubeconfig files"
echo "#######################################################################################################"
kubectl create -f YAML/tenant1.yaml
kubectl create -f YAML/tenant2.yaml
echo; echo
kubectl get tenants
echo; echo
sh create-user.sh owner1 tenant1
sh create-user.sh owner2 tenant2
EOF




cat > 4_deploy_app1_tenant1.sh << EOF
echo "#######################################################################################################"
echo " Can we list the namespace and storage class"
echo "#######################################################################################################"
kubectl --kubeconfig owner1-tenant1.kubeconfig get ns
kubectl --kubeconfig owner1-tenant1.kubeconfig get sc

echo "#######################################################################################################"
echo " Let's deploy an app in tenant1"
echo "#######################################################################################################"
kubectl --kubeconfig owner1-tenant1.kubeconfig create ns tenant1-ghost1
sleep 5s

kubectl --kubeconfig owner1-tenant1.kubeconfig create -n tenant1-ghost1 -f Tenant1_Ghost1/1-ghost_tenant1-pvc.yaml
kubectl --kubeconfig owner1-tenant1.kubeconfig create -n tenant1-ghost1 -f Tenant1_Ghost1/2-ghost_tenant1-svc.yaml

sleep 5s
TENANT1_GHOST_SERVICE_IP=\$(kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost1 svc blog-tenant1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i s,GHOST_SERVICE_IP,\$TENANT1_GHOST_SERVICE_IP, Tenant1_Ghost1/3-ghost_tenant1-deploy.yaml

kubectl --kubeconfig owner1-tenant1.kubeconfig create -n tenant1-ghost1 -f Tenant1_Ghost1/3-ghost_tenant1-deploy.yaml

echo "#######################################################################################################"
echo " What do we see as a tenant owner"
echo "#######################################################################################################"
kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost1 svc,pod,pvc

echo "#######################################################################################################"
echo " What do we see as a the kubernetes admin: NAMESPACES"
echo "#######################################################################################################"
kubectl get ns

echo "#######################################################################################################"
echo " What do we see as a the kubernetes admin: CONTENT OF NAMESPACE tenant1-ghost1"
echo "#######################################################################################################"
kubectl get svc,pod,pvc -n tenant1-ghost1
EOF


cat > 4_deploy_app1_tenant1_CHECK.sh << EOF
kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost1 svc,pod,pvc
EOF




cat > 5_deploy_app_tenant2.sh << EOF
echo "#######################################################################################################"
echo " Let's deploy an app in tenant2"
echo "#######################################################################################################"
kubectl --kubeconfig owner2-tenant2.kubeconfig create ns tenant2-bbox
sleep 5s

kubectl --kubeconfig owner2-tenant2.kubeconfig create -n tenant2-bbox -f Tenant2_Busybox/pvc.yaml
kubectl --kubeconfig owner2-tenant2.kubeconfig create -n tenant2-bbox -f Tenant2_Busybox/pod-busybox-nas.yaml

echo "#######################################################################################################"
echo " What do we see as a tenant owner"
echo "#######################################################################################################"
kubectl --kubeconfig owner2-tenant2.kubeconfig get -n tenant2-bbox pod,pvc

echo "#######################################################################################################"
echo " Can I access the environment of Tenant1"
echo "#######################################################################################################"
kubectl --kubeconfig owner2-tenant2.kubeconfig get -n tenant1-ghost1 svc,pod,pvc
EOF


cat > 5_deploy_app_tenant2_CHECK.sh << EOF
kubectl --kubeconfig owner2-tenant2.kubeconfig get -n tenant2-bbox pod,pvc
EOF


cat > 6_deploy_app2_tenant1.sh << EOF
echo "#######################################################################################################"
echo " Let's deploy another app in tenant1"
echo "#######################################################################################################"
kubectl --kubeconfig owner1-tenant1.kubeconfig create ns tenant1-ghost2
sleep 5s

kubectl --kubeconfig owner1-tenant1.kubeconfig create -n tenant1-ghost2 -f Tenant1_Ghost2/1-ghost2_tenant1-pvc.yaml
kubectl --kubeconfig owner1-tenant1.kubeconfig create -n tenant1-ghost2 -f Tenant1_Ghost2/2-ghost2_tenant1-svc.yaml

sleep 5s
TENANT1_GHOST2_SERVICE_IP=\$(kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost2 svc blog2-tenant1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i s,GHOST_SERVICE_IP,\$TENANT1_GHOST2_SERVICE_IP, Tenant1_Ghost2/3-ghost2_tenant1-deploy.yaml

kubectl --kubeconfig owner1-tenant1.kubeconfig create -n tenant1-ghost2 -f Tenant1_Ghost2/3-ghost2_tenant1-deploy.yaml

echo "#######################################################################################################"
echo " What do we see as a tenant owner"
echo "#######################################################################################################"
echo;echo "----------- TENANT1:";echo
kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost1 svc,pod,pvc
echo;echo "----------- TENANT2:";echo
kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost2 svc,pod,pvc

echo "#######################################################################################################"
echo " What do we see as a the kubernetes admin: CONTENT OF NAMESPACE tenant1-ghost2"
echo "#######################################################################################################"
kubectl get svc,pod,pvc -n tenant1-ghost2
EOF

cat > 6_deploy_app2_tenant1_CHECK.sh << EOF
kubectl --kubeconfig owner1-tenant1.kubeconfig get -n tenant1-ghost2 svc,pod,pvc
EOF

cat > 7_snap_app1_tenant1.sh << EOF
echo "#######################################################################################################"
echo " Can I by default take CSI Snapshots in a Capsule tenant"
echo "#######################################################################################################"
kubectl --kubeconfig owner1-tenant1.kubeconfig -n tenant1-ghost1 create -f Tenant1_Ghost1/pvc_snapshot.yaml
echo
read -rsp \$'Press any key to continue ...\n' -n1 key

echo "#######################################################################################################"
echo " Nope, let's give the tenant the CSI Snapshot capability & retry"
echo "#######################################################################################################"
kubectl create -f YAML/clusterrole_volumesnapshots.yaml
kubectl describe clusterrole capsule-volume-snapshot -n tenant1-ghost1
kubectl patch tenant/tenant1 --type=merge --patch-file YAML/tenant1_patch.yaml
sleep 3s

kubectl --kubeconfig owner1-tenant1.kubeconfig -n tenant1-ghost1 create -f Tenant1_Ghost1/pvc_snapshot.yaml
kubectl --kubeconfig owner1-tenant1.kubeconfig -n tenant1-ghost1 create -f Tenant1_Ghost1/pvc_from_snap.yaml
kubectl --kubeconfig owner1-tenant1.kubeconfig -n tenant1-ghost1 get pvc,volumesnapshot
EOF


cp ~/.bashrc ~/.bashrc.bak
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
bash