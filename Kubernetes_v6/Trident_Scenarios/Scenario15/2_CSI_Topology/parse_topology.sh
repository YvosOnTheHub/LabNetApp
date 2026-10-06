#!/bin/bash

NS=topology

if ! kubectl get ns "$NS" &>/dev/null; then
    echo "Namespace $NS not found" >&2
    exit 1
fi

count() {
    kubectl get "$1" -n "$NS" --no-headers "${@:2}" 2>/dev/null | wc -l | tr -d ' '
}

echo "pods_total: $(count pods)"
echo "pods_running: $(count pods --field-selector=status.phase=Running)"
echo "pods_pending: $(count pods --field-selector=status.phase=Pending)"
echo "pvc_total: $(count pvc)"
echo "pvc_bound: $(kubectl get pvc -n "$NS" --no-headers 2>/dev/null | awk '$2=="Bound"{n++} END{print n+0}')"
