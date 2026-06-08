echo
echo "############################################"
echo "### Trident Protect install"
echo "############################################"
cd

cat <<EOF >> protectValues_rhel5.yaml
imageRegistry: registry.demo.netapp.com
imagePullSecrets:
- name: regcred
nodeSelector:
  kubernetes.io/os: linux
EOF

kubectl create ns trident-protect --kubeconfig=/root/.kube/config_rhel5
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com --kubeconfig=/root/.kube/config_rhel5

helm install trident-protect netapp-trident-protect/trident-protect \
  --set clusterName=lod2 \
  --version 100.2602.1 \
  --namespace trident-protect -f protectValues_rhel5.yaml --kubeconfig=/root/.kube/config_rhel5

echo
echo "############################################"
echo "### Protectctl install"
echo "############################################"
cd
scp -p /usr/local/bin/tridentctl-protect rhel5:/usr/local/bin/tridentctl-protect

ssh -o "StrictHostKeyChecking no" root@rhel5 "mkdir -p ~/.bash/completions"
ssh -o "StrictHostKeyChecking no" root@rhel5 "tridentctl-protect completion bash > ~/.bash/completions/tridentctl-protect-completion.bash"
ssh -o "StrictHostKeyChecking no" root@rhel5 "source ~/.bash/completions/tridentctl-protect-completion.bash"
ssh -o "StrictHostKeyChecking no" root@rhel5 "echo 'source ~/.bash/completions/tridentctl-protect-completion.bash' >> ~/.bashrc"

frames="/ | \\ -"
while [ $(kubectl get -n trident-protect pod --kubeconfig=/root/.kube/config_rhel5 | grep Running | grep -e '1/1' | wc -l) -ne 1 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident Protect to be ready $frame" 
    done
done
echo
echo "Trident Protect is installed on RHEL5"
echo