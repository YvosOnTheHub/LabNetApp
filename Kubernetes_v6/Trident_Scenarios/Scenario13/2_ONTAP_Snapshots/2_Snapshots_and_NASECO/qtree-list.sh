PVC1INTERNALID=$(kubectl get pv $( kubectl get pvc pvc1 -n bbox1 -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalID}')
QTREEPOOL=$(echo $PVC1INTERNALID | awk -F '/' '{print $5}')
echo "FLEXVOL NAME:"
echo $QTREEPOOL
QTREESAPI=$(curl -s -X GET -ku admin:Netapp1! "https://cluster1.demo.netapp.com/api/storage/qtrees?volume.name=$QTREEPOOL" -H "accept: application/json")
echo "QTREES:"
echo $QTREESAPI | jq -c '.records[] | select(.id!=0)' | jq -r .name