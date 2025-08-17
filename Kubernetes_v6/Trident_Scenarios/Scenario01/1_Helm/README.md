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
Trident 24.02 is already installed with a Helm chart.  
```bash
$ helm ls -n trident
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
trident trident         1               2024-04-27 21:03:54.470749763 +0000 UTC deployed        trident-operator-100.2402.0     24.02.0
```

Next, the exercise will use the local private repository. If not done yet, we first need to pull the right Trident images, tag them & finally push them to _registry.demo.netapp.com_ (cf script *scenario01_pull_images.sh* in the Scenario01 folder):  
```bash
$ sh ../scenario01_pull_images.sh 
```

Also, this registry requires credentials to retrieve images. The linux nodes already have them saved locally, however the windows nodes do not have that information. Hence, we will create a secret so that the Trident operator can pull images locally:  
```bash
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com
secret/regcred created
```
We are now ready to proceed with the upgrade:  
```bash
$ helm repo update netapp-trident
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "netapp-trident" chart repository
Update Complete. ⎈Happy Helming!⎈

$ helm upgrade trident netapp-trident/trident-operator --version 100.2506.1 -n trident --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:25.06.0,operatorImage=registry.demo.netapp.com/trident-operator:25.06.1,tridentImage=registry.demo.netapp.com/trident:25.06.1,tridentSilenceAutosupport=true,windows=true,imagePullSecrets[0]=regcred
NAME: trident
LAST DEPLOYED: Wed Jul 16 14:42:46 2025
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
trident trident         2               2025-08-07 14:21:46.138636676 +0000 UTC deployed        trident-operator-100.2506.1     25.06.1
```

Quite easy !  
The upgrade takes about 5 minutes to complete.  

Once finished, let's check what we have:  
```bash
$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 25.06.1        | 25.06.1        |
+----------------+----------------+

$ kubectl describe torc trident -n trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  trident
  Status:     Installed
  Version:    v25.06.1
```

## What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)