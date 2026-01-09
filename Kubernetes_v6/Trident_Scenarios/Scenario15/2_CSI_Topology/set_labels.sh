label=$(kubectl get node rhel1 -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/region}' 2>/dev/null || true)
if [ "$label" != "dc" ]; then
    kubectl label node rhel1 "topology.kubernetes.io/region=dc" --overwrite
    kubectl label node rhel1 "topology.kubernetes.io/zone=west" --overwrite
    kubectl delete -n trident pod -l app=node.csi.trident.netapp.io  --field-selector spec.nodeName=rhel1
fi

label=$(kubectl get node rhel2 -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/region}' 2>/dev/null || true)
if [ "$label" != "dc" ]; then
    kubectl label node "rhel2" "topology.kubernetes.io/region=dc" --overwrite
    kubectl label node "rhel2" "topology.kubernetes.io/zone=west" --overwrite
    kubectl delete -n trident pod -l app=node.csi.trident.netapp.io  --field-selector spec.nodeName=rhel2
fi

label=$(kubectl get node rhel3 -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/region}' 2>/dev/null || true)
if [ "$label" != "dc" ]; then
    kubectl label node "rhel3" "topology.kubernetes.io/region=dc" --overwrite
    kubectl label node "rhel3" "topology.kubernetes.io/zone=east" --overwrite
    kubectl delete -n trident pod -l app=node.csi.trident.netapp.io  --field-selector spec.nodeName=rhel3
fi

if kubectl get node rhel4 &>/dev/null; then
    label=$(kubectl get node rhel4 -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/region}' 2>/dev/null || true)
    if [ "$label" != "dc" ]; then
        kubectl label node "rhel4" "topology.kubernetes.io/region=dc" --overwrite
        kubectl label node "rhel4" "topology.kubernetes.io/zone=east" --overwrite
        kubectl delete -n trident pod -l app=node.csi.trident.netapp.io  --field-selector spec.nodeName=rhel4
    fi
fi