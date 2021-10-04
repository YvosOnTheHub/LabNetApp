#########################################################################################
# SCENARIO 1: Trident installation with Helm
#########################################################################################

Helm is a package manager that is very popular when it comes to Kubernetes. You can easily deploy your application & all its objects with just one command.  
Also, the Trident Operator Helm Chart has been available on the artifact hub since v21.01:
https://artifacthub.io/packages/helm/netapp-trident/trident-operator

Helm is already present in the LabOnDemand:

```bash
$ helm version
version.BuildInfo{Version:"v3.0.3", GitCommit:"ac925eb7279f4a6955df663a0128044a8a6b7593", GitTreeState:"clean", GoVersion:"go1.13.6"}
```

In order to install Trident with Helm, we first need to clean up the environment, ie remove Trident & all related objects.  
To do so, you can simply you the script _trident_uninstall.sh_ that will do the job for you.

We also need to re-create the _trident_ namespace before the installation.  
For information, Helm 3.2 introduced a new parameter called _--create-namespace_.  

```bash
$ kubectl create namespace trident
namespace/trident created

$ helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
"netapp-trident" has been added to your repositories

$ helm install trident netapp-trident/trident-operator --version 21.7.2 -n trident
NAME: trident
LAST DEPLOYED: Mon Aug  22 07:46:38 2021
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
trident trident         1               2021-08-22 07:46:38.154347422 +0000 UTC deployed        trident-operator-21.07.2        21.07.2
```

Also quite easy !  
Let's check what we have:

```bash
$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 21.07.2        | 21.07.2        |
+----------------+----------------+

$ kubectl describe torc trident -n trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  trident
  Status:     Installed
  Version:    v21.07.2
```

## What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)