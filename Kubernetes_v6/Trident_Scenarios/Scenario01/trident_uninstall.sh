frames="/ | \\ -"

tridentctl -n trident delete backends --all
kubectl delete sc --all

echo
helm delete trident -n trident
while [ $(kubectl get -n trident pod --no-headers | wc -l) -ne 0 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the Trident namespace to be empty $frame" 
    done
done
sleep 5

tridentctl obliviate crd --yesireallymeanit
while [ $(kubectl get crd | grep trident. | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the Trident CRDs to be deleted $frame" 
    done
done
sleep 5

kubectl delete crd tridentorchestrators.trident.netapp.io

echo
kubectl delete ns trident
while kubectl get ns trident >/dev/null 2>&1; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for the Trident namespace to be deleted $frame" 
    done
done



