#!/bin/bash

cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario05

echo "#######################################################################################################"
echo "Multipathing"
echo "#######################################################################################################"

sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
mpathconf --enable --with_multipathd y --find_multipaths n
systemctl enable --now multipathd

ssh -o "StrictHostKeyChecking no" root@rhel1 "sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf"
ssh -o "StrictHostKeyChecking no" root@rhel1 "mpathconf --enable --with_multipathd y --find_multipaths n"
ssh -o "StrictHostKeyChecking no" root@rhel1 "systemctl enable --now multipathd"

ssh -o "StrictHostKeyChecking no" root@rhel2 "sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf"
ssh -o "StrictHostKeyChecking no" root@rhel2 "mpathconf --enable --with_multipathd y --find_multipaths n"
ssh -o "StrictHostKeyChecking no" root@rhel2 "systemctl enable --now multipathd"

echo "#######################################################################################################"
echo "Creating SAN Backends with kubectl"
echo "#######################################################################################################"

kubectl create -n trident -f secret_ontap_iscsi-svm_chap.yaml
kubectl create -n trident -f backend_san-secured.yaml
kubectl create -n trident -f backend_san-eco.yaml

echo "#######################################################################################################"
echo "Creating SAN Storage Class"
echo "#######################################################################################################"

kubectl create -f sc-csi-ontap-san.yaml
kubectl create -f sc-csi-ontap-san-eco.yaml
