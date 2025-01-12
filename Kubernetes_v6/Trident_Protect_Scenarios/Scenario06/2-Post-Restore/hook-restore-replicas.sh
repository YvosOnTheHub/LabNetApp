#!/bin/sh

# This script changes the number of replicas of a deployment 
#
# This script is tailormade for this scenario. Check out https://github.com/NetApp/Verda for more hooks


scale_replicas_per_object() {
    object=$1
    replicas=$2

    # Scale the desired deployment
    kubectl scale deploy ${object} --replicas="${replicas}"
}

scale_replicas() {
    deploy=$1
    replicas=$2

    objects=$(kubectl get deployments -o json | jq -r --arg dep "$deploy" '.items[].metadata | select(.name | endswith($dep)) | .name')

    for object in ${objects}; do
        echo "$(date): KUBERNETES DEPLOY NAME TO SCALE: ${object}" >> /var/log/acc-logs-hooks.log
        scale_replicas_per_object "${object}" "${replicas}"
    done
}


#
# main
#

# check arg
deploy=$1
replicas=$2
if [ -z "${deploy}" ] || [ -z "${replicas}" ]; then
    echo "Usage: $0 <deployment name> <replicas>"
    exit 
fi

echo "$(date): ========= HOOK REPLICAS SCALE START ===========" >> /var/log/acc-logs-hooks.log
echo "$(date): APP TO SCALE: $1" >> /var/log/acc-logs-hooks.log
echo "$(date): NUMBER OF REPLICAS: $2" >> /var/log/acc-logs-hooks.log

scale_replicas "${deploy}" "${replicas}"

echo "$(date): ========= HOOK REPLICAS SCALE END ===========" >> /var/log/acc-logs-hooks.log