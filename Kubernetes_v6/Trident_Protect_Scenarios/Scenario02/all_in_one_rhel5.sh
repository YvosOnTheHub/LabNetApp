echo
echo "############################################"
echo "### Trident Protect install"
echo "############################################"
cd

cat <<EOF >> protectValues.yaml
image:
  registry: registry.demo.netapp.com
imagePullSecrets:
- name: regcred
controller:
  image:
    registry: registry.demo.netapp.com
rbacProxy:
  image:
    registry: registry.demo.netapp.com
crCleanup:
  imagePullSecrets:
  - name: regcred
webhooksCleanup:
  imagePullSecrets:
  - name: regcred
EOF

kubectl create ns trident-protect
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/
helm registry login registry.demo.netapp.com -u registryuser -p Netapp1!
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com

helm install trident-protect-crds netapp-trident-protect/trident-protect-crds --version 100.2410.0 --namespace trident-protect
helm install trident-protect netapp-trident-protect/trident-protect \
  --set clusterName=lod2 \
  --version 100.2410.0 \
  --namespace trident-protect -f protectValues.yaml

echo
echo "############################################"
echo "### Protectctl install"
echo "############################################"
cd
curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/24.10.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin

curl -L -O https://github.com/NetApp/tridentctl-protect/releases/download/24.10.0/tridentctl-completion.bash
mkdir -p ~/.bash/completions
mv tridentctl-completion.bash ~/.bash/completions/
source ~/.bash/completions/tridentctl-completion.bash

cat <<EOT >> ~/.bashrc
source ~/.bash/completions/tridentctl-completion.bash
EOT

frames="/ | \\ -"
while [ $(kubectl get -n trident-protect pod | grep Running | grep -e '2/2' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident Protect to be ready $frame" 
    done
done
echo
echo "Trident Protect is installed on RHEL5"
echo