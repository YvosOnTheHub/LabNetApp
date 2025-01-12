#!/bin/sh

# This script currently swaps all container images between $tag1 and $tag2 when invoked.
# Order does not matter, if $tag1 is active at the time of invocation, then $tag2 will be the
# new tag. If $tag2 is active, then $tag1 becomes the new active tag.
#
# This script is tailormade for this scenario. Check out https://github.com/NetApp/Verda for more hooks

swap_tags_per_container() {
    tag1=$1
    tag2=$2
    category=$3
    object=$4
    c=$5

    # Get the image and image tag
    full_image=$(kubectl get ${category} ${object} -o json | jq -r --arg con "$c" '.spec.template.spec.containers[] | select(.name == $con) | .image')
    tag=$(echo ${full_image} | cut -d ":" -f 2)
    image=$(echo ${full_image} | cut -d ":" -f -1)
    echo "$(date):    INITIAL IMAGE: $full_image" >> /var/log/acc-logs-hooks.log

    # Swap the tag
    if [ ${tag} = ${tag1} ] ; then
        new_tag=${tag2}
    else
        new_tag=${tag1}
    fi
    echo "$(date):    TARGET TAG: $new_tag" >> /var/log/acc-logs-hooks.log

    # Rebuild the image string
    new_full_image=$(echo ${image}:${new_tag})
    echo "$(date):    NEW IMAGE: $new_full_image" >> /var/log/acc-logs-hooks.log

    # Update the image
    kubectl set image ${category}/${object} ${c}=${new_full_image}
}

swap_tags_per_object() {
    tag1=$1
    tag2=$2
    category=$3
    object=$4

    # Loop through the containers within an object
    containerNames=$(kubectl get $category ${object} -o json | jq -r '.spec.template.spec.containers[].name')
    for c in ${containerNames}; do
        echo "$(date): OBJECT TO SWAP: ${category} ${object}: container '${c}'" >> /var/log/acc-logs-hooks.log
        swap_tags_per_container "${tag1}" "${tag2}" "${category}" "${object}" "${c}"
    done
}

swap_tags() {
    tag1=$1
    tag2=$2

    deploys=$(kubectl get deployments -o json | jq -r '.items[].metadata | select(.name != "astra-hook-deployment") | .name')
    stss=$(kubectl get statefulset -o json | jq -r '.items[].metadata.name')

    for object in ${deploys}; do
        swap_tags_per_object "${tag1}" "${tag2}" deploy "${object}"
    done

    for object in ${stss}; do
        swap_tags_per_object "${tag1}" "${tag2}" sts "${object}"
    done

}


#
# main
#

# check arg
tag1=$1
tag2=$2
if [ -z "${tag1}" ] || [ -z "${tag2}" ]; then
    echo "Usage: $0 <tag1> <tag2>"
    exit 
fi

echo "$(date): ========= HOOK TAG REWRITE START ===========" >> /var/log/acc-logs-hooks.log
echo "$(date): PARAMETER1: $1" >> /var/log/acc-logs-hooks.log
echo "$(date): PARAMETER2: $2" >> /var/log/acc-logs-hooks.log

swap_tags "${tag1}" "${tag2}"

echo "$(date): ========= HOOK TAG REWRITE END ===========" >> /var/log/acc-logs-hooks.log