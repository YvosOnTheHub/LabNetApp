#########################################################################################
# SCENARIO 1: Trident installation with Helm
#########################################################################################

Helm is a package manager that is very popular when it comes to Kubernetes. You can easily deploy your application & all its objects with just one command.  
Also, the Trident Operator Helm Chart has been available on the artifact hub since v21.01:
https://artifacthub.io/packages/helm/netapp-trident/trident-operator

Helm is already present in the LabOnDemand:

```bash
$ helm version
version.BuildInfo{Version:"v3.7.1", GitCommit:"1d11fcb5d3f3bf00dbe6fe31b8412839a96b3dc4", GitTreeState:"clean", GoVersion:"go1.16.9"}
```

In order to install Trident with Helm, we first need to clean up the environment, ie remove Trident & all related objects.  
To do so, you can simply you the script _trident_uninstall.sh_ that will do the job for you.

Next, the exercise will use the local private repository (cd host _rhel4_). If not done yet, we first need to pull the right Trident images, tag them & finally push them to _registry.demo.netapp.com_ (cf script _scenario01_pull_images.sh_ in the Scenario01 folder).

```bash
$ sh ../scenario01_pull_images.sh 

$ helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
"netapp-trident" has been added to your repositories

$ helm install trident netapp-trident/trident-operator --version 23.07.1 -n trident --create-namespace --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:23.07.0,operatorImage=registry.demo.netapp.com/trident-operator:23.07.1,tridentImage=registry.demo.netapp.com/trident:23.07.1
NAME: trident
LAST DEPLOYED: Fri Sept 8 12:09:12 2023
NAMESPACE: trident
STATUS: deployed
REVISION: 1
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
trident trident         1               2023-09-08 12:09:12.353436649 +0000 UTC deployed        trident-operator-23.07.1        23.07.1
```

Also quite easy !  
Let's check what we have:

```bash
$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 23.07.1        | 23.07.1        |
+----------------+----------------+

$ kubectl describe torc trident -n trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  trident
  Status:     Installed
  Version:    v23.07.1
```

## What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)