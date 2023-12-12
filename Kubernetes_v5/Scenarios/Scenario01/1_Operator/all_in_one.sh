#!/bin/bash

# OPTIONAL PARAMETERS: 
# - PARAMETER1: Docker hub login
# - PARAMETER2: Docker hub password

if [[ $(yum info jq -y 2> /dev/null | grep Repo | awk '{ print $3 }') != "installed" ]]; then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi

if [[  $(docker images | grep registry | grep trident | grep 23.07.1 | wc -l) -eq 0 ]]; then
  if [ $# -eq 2 ]; then
    sh ../scenario01_pull_images.sh $1 $2  
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
      sh ../scenario01_pull_images.sh
    fi
  fi
fi

echo "#######################################################################################################"
echo "Add Region & Zone labels to Kubernetes nodes"
echo "#######################################################################################################"

kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite

kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite

if [ $(kubectl get nodes | wc -l) = 5 ]; then
  kubectl label node rhel4 "topology.kubernetes.io/region=east" 
  kubectl label node rhel4 "topology.kubernetes.io/zone=east1" 
fi

echo "#######################################################################################################"
echo "Add a second iSCSI Data LIF to the SVM"
echo "#######################################################################################################"

curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "ip": { "address": "192.168.0.140", "netmask": "24" },
  "location": {
    "home_port": {
      "name": "e0d",
      "node": { "name": "cluster1-01" }
    }
  },
  "name": "iscsi_svm_iscsi_02",
  "scope": "svm",
  "service_policy": { "name": "default-data-blocks" },
  "svm": { "name": "iscsi_svm" }
}' "https://cluster1.demo.netapp.com/api/network/ip/interfaces"

echo "#######################################################################################################"
echo "Hosts Multipathing Configuration"
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
echo "Download Trident 23.07.1"
echo "#######################################################################################################"

cd
mkdir 23.07.1 && cd 23.07.1
wget https://github.com/NetApp/trident/releases/download/v23.07.1/trident-installer-23.07.1.tar.gz
tar -xf trident-installer-23.07.1.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo "#######################################################################################################"
echo "Remove current Trident Operator (21.10.0)"
echo "#######################################################################################################"

kubectl delete -f ~/21.10.0/trident-installer/deploy/bundle.yaml

echo "#######################################################################################################"
echo "Customize the orchestator to reflect the use of a private repository"
echo "#######################################################################################################"

kubectl -n netapp patch torc/trident --type=json -p='[ 
    {"op":"add", "path":"/spec/tridentImage", "value":"registry.demo.netapp.com/trident:23.07.1"}, 
    {"op":"add", "path":"/spec/autosupportImage", "value":"registry.demo.netapp.com/trident-autosupport:23.07.0"}
]'

echo "#######################################################################################################"
echo "Install new Trident Operator (23.07.1)"
echo "#######################################################################################################"

sed -i s,netapp\/,registry.demo.netapp.com\/, ~/23.07.1/trident-installer/deploy/bundle_pre_1_25.yaml
kubectl create -f ~/23.07.1/trident-installer/deploy/bundle_pre_1_25.yaml

echo "#######################################################################################################"
echo "Check"
echo "#######################################################################################################"

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '6/6' | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
tridentctl -n trident version

echo "#######################################################################################################"
echo "Delete existing backends & storage classes"
echo "#######################################################################################################"

kubectl delete sc --all
tridentctl -n trident delete backend --all