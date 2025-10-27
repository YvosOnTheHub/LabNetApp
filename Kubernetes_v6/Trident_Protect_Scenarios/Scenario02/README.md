#########################################################################################
# SCENARIO 2: Trident Protect installation
#########################################################################################

Trident Protect is simply installed with a Helm chart.  
It uses multiple containers images to perform various application management tasks. 
Let's pull all the required images from the docker hub & use the lab private registry when installing Trident Protect.  
This folder contains a script to perform that task:  
```bash
sh scenario02_pull_images.sh 
```

In order to point our app to the private registry, we will first create a secret with its credentials:  
```bash
kubectl create ns trident-protect
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com
```
We are now ready to install Trident Protect with Helm.  
We are going to use parameters gathered in the *trident_protect_helm_values.yaml* file.  
They essentially point the installer to the registry, while specifying the secret to access it.  
```bash
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/
helm registry login registry.demo.netapp.com -u registryuser -p Netapp1!

helm install trident-protect netapp-trident-protect/trident-protect \
  --set clusterName=lod1 \
  --version 100.2506.0 \
  --namespace trident-protect -f trident_protect_helm_values.yaml
```
After a few seconds (really), you will see a pod in the Trident Protect namespace:  
```bash
$ kubectl get -n trident-protect po
NAME                                                           READY   STATUS    RESTARTS   AGE
trident-protect-controller-manager-6454f4776f-6ls7v            2/2     Running   0          1h
```
You can use the same method on the secondary cluster if you have created one.  
In this case, make sure you set a different value for the _clusterName_ parameter (_lod2_ for instance).  


Trident Protect CR can be configured with YAML manifests or CLI.  
Let's install its CLI which avoids making mistakes when creating the YAML files:  
```bash
cd
curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/25.06.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin

curl -L -O https://github.com/NetApp/tridentctl-protect/releases/download/25.02.0/tridentctl-completion.bash
mkdir -p ~/.bash/completions
mv tridentctl-completion.bash ~/.bash/completions/
source ~/.bash/completions/tridentctl-completion.bash

cat <<EOT >> ~/.bashrc
source ~/.bash/completions/tridentctl-completion.bash
EOT
```

The CLI will appear as a new sub-menu in the _tridentctl_ tool.  
```bash
$ tridentctl-protect version
25.06.0
```

There are 2 scripts in this folder that can perform the installation automatically:  
- _all_in_one_rhel3.sh_: installs Trident Protect on RHEL3  
- _all_in_one_rhel5.sh_: installs Trident Protect on RHEL5