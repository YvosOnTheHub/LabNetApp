#!/bin/bash
# Usage: topo.sh [namespace]
# Counts pods and PVCs in a namespace. Defaults to "topology".

NS="${1:-topology}"

if ! kubectl get ns "$NS" &>/dev/null; then
    echo "Namespace $NS not found" >&2
    exit 1
fi

pod_phases=$(kubectl get pods -n "$NS" -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}')
pvc_phases=$(kubectl get pvc -n "$NS" -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}')

count() {
    printf '%s\n' "$1" | awk -v phase="$2" 'NF && (phase == "" || $1 == phase) { n++ } END { print n + 0 }'
}

echo "pods_total: $(count "$pod_phases")"
echo "pods_running: $(count "$pod_phases" Running)"
echo "pods_pending: $(count "$pod_phases" Pending)"
echo "pvc_total: $(count "$pvc_phases")"
echo "pvc_bound: $(count "$pvc_phases" Bound)"
