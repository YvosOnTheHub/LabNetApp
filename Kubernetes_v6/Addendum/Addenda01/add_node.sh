#!/bin/bash

# PARAMETER1: name of the host to add

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: Host to add to the cluster"
    exit 0
fi

KUBEADMJOIN=$(kubeadm token create --print-join-command)
ssh -o "StrictHostKeyChecking no" root@$1 $KUBEADMJOIN

while [ $(kubectl get nodes | grep NotReady | wc -l) -eq 1 ]
do
  echo "sleeping a bit - waiting for all nodes to be ready ..."
  sleep 5
done