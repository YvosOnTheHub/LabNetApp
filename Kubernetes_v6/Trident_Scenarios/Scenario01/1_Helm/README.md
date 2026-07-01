#########################################################################################
# SCENARIO 1: Trident upgrade with Helm
#########################################################################################

Helm is a package manager that is very popular when it comes to Kubernetes. You can easily deploy your application & all its objects with just one command.  
Also, the Trident Operator Helm Chart has been available on the artifact hub since v21.01:
https://artifacthub.io/packages/helm/netapp-trident/trident-operator

Helm is already present in the LabOnDemand:  
```bash
$ helm version
version.BuildInfo{Version:"v3.9.4", GitCommit:"dbc6d8e20fe1d58d50e6ed30f09a04a77e4c68db", GitTreeState:"clean", GoVersion:"go1.17.13"}
```
It is however recommened to upgrade Helm to a more recent version in order to avoid issues later in the lab:  
```bash
wget https://get.helm.sh/helm-v4.0.5-linux-amd64.tar.gz
tar -xvf helm-v4.0.5-linux-amd64.tar.gz
/bin/cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v4.0.5-linux-amd64.tar.gz
```
You should now see the following:  
```bash
$ helm version --short
v4.0.5+g1b6053d
```

As Trident was uninstalled, the following should not return any result:    
```bash
$ helm ls -n trident
```

Next, the exercise will use the local private repository. If not done yet, we first need to pull the right Trident images, tag them & finally push them to _registry.demo.netapp.com_ (cf script *scenario01_pull_images.sh* in the Scenario01 folder):  
```bash
$ sh ../scenario01_pull_images.sh 
```

Also, this registry requires credentials to retrieve images. The linux nodes already have them saved locally, however the windows nodes do not have that information. Hence, we will create a secret so that the Trident operator can pull images locally:  
```bash
$ kubectl create ns trident
$ kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com
secret/regcred created
```
We are now ready to proceed with the upgrade:  
```bash
$ helm repo update netapp-trident
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "netapp-trident" chart repository
Update Complete. ⎈Happy Helming!⎈

$ helm upgrade --install trident netapp-trident/trident-operator --version 100.2606.0 -n trident --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:26.06.0,operatorImage=registry.demo.netapp.com/trident-operator:26.06.0,tridentImage=registry.demo.netapp.com/trident:26.06.0,tridentSilenceAutosupport=true,windows=true,imagePullSecrets[0]=regcred
NAME: trident
LAST DEPLOYED: Tue Jun 30 18:01:07 2026
NAMESPACE: trident
STATUS: deployed
REVISION: 2
TEST SUITE: None
NOTES:
Thank you for installing trident-operator, which will deploy and manage NetApp's Trident CSI
storage provisioner for Kubernetes.

Your release is named 'trident' and is installed into the 'default' namespace.
Please note that there must be only one instance of Trident (and trident-operator) in a Kubernetes cluster.

To configure Trident to manage storage resources, you will need a copy of tridentctl, which is
available in pre-packaged Trident releases.  You may find all Trident releases and source code
online at https://github.com/NetApp/trident.

To learn more about the release, try:

  $ helm status trident
  $ helm get all trident

$ helm ls -n trident
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
trident trident         2               2026-06-30 18:01:07.714962103 +0000 UTC deployed        trident-operator-100.2606.0     26.06.0
```

Quite easy !  
The upgrade takes about 5 minutes to complete.  

Once finished, let's check what we have:  
```bash
$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 26.06.0        | 26.06.0        |
+----------------+----------------+

$ kubectl describe torc trident -n trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  trident
  Status:     Installed
  Version:    v26.06.0
```
<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>  

**In resource constraint environments, such as this lab, a race condition may not populate all Trident keys when CSI Topology is enabled. If that was the case, creating a PVC would fail.**
<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p> 

As CSI Topology is enabled on this lab, you can check whether the configuration is complete.:  
```bash
$ kubectl get csinode rhel1 -o yaml | grep -C3 topologyKeys
  drivers:
  - name: csi.tigera.io
    nodeID: rhel1
    topologyKeys: null
  - name: csi.trident.netapp.io
    nodeID: rhel1
    topologyKeys: null
```
The **topologyKeys** Trident parameter is empty for the node _rhel1_, when it should contain some content.  
In order to fix this, you can rollout the Trident DaemonSet, operation that will read again the topology parameters:  
```bash
$ kubectl rollout restart ds/trident-node-linux -n trident
daemonset.apps/trident-node-linux restarted
```
All the Trident DaemonSets will restart. Once done, you can if the configuration is now correct:  
```bash
$ kubectl get csinode rhel1 -o yaml | grep -C3 topologyKeys
  drivers:
  - name: csi.tigera.io
    nodeID: rhel1
    topologyKeys: null
  - name: csi.trident.netapp.io
    nodeID: rhel1
    topologyKeys:
    - topology.kubernetes.io/region
    - topology.kubernetes.io/zone
```
Alright, now Trident is ready!  

## What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)