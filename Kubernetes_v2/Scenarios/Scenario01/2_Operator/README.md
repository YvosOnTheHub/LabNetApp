#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

**GOAL:**  
With Trident 20.07, it is now possible to an Operator to upgrade from non-Operator based architectures.  
Before moving to the upgrade, we will first need to delete & clean up the current deployment.  

## A. Cleanup up Trident & Download the new version

*tridenctlctl* is the tool shipped with Trident in order to interact with it.  
It is also recommended to install Trident in its own namespace (usually called *trident*)

```bash
$ tridentctl -n trident version 
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 19.07.1        | 19.07.1        |
+----------------+----------------+
```

In this example, we will remove some objects linked to Trident 19.07.1.  
I will consider that there is no PVC configured with Trident.  

First, let's remove all current Kubernetes storage classes & Tridents' backends (this is optional)

```bash
kubectl delete sc --all
tridentctl -n trident delete backend --all
```

Download the version you would like to install

```bash
cd
mv trident-installer/ trident-installer_19.07
wget https://github.com/NetApp/trident/releases/download/v20.07.0/trident-installer-20.07.0.tar.gz
tar -xf trident-installer-20.07.0.tar.gz
```

Finally, remove the CRD related to the Snapshot alpha feature.

```bash
$ tridentctl -n trident obliviate alpha-snapshot-crd
INFO CRD deleted.                                  CRD=volumesnapshotclasses.snapshot.storage.k8s.io
INFO CRD deleted.                                  CRD=volumesnapshotcontents.snapshot.storage.k8s.io
INFO CRD deleted.                                  CRD=volumesnapshots.snapshot.storage.k8s.io
```

:mag:  
*A* **resource** *is an endpoint in the Kubernetes API that stores a collection of API objects of a certain kind; for example, the built-in pods resource contains a collection of Pod objects.*  
*A* **custom resource** *is an extension of the Kubernetes API that is not necessarily available in a default Kubernetes installation. It represents a customization of a particular Kubernetes installation. However, many core Kubernetes functions are now built using custom resources, making Kubernetes more modular.*  
:mag_right:  

You can now upgrade Trident :trident:  

## C. Upgrade Trident

Let's first check the version of Kubernetes you are using:

```bash
$ kubectl get nodes
NAME    STATUS   ROLES    AGE    VERSION
rhel1   Ready    <none>   294d   v1.15.3
rhel2   Ready    <none>   294d   v1.15.3
rhel3   Ready    master   294d   v1.15.3
```

The CRD object was promoted to GA with Kubernetes 1.16.  
Depending on the current version of Kubernetes you are running, you will need to use one of the 2 following commands in order to install the Trident Provsioner CRD.

```bash
$ kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentprovisioners_crd_pre1.16.yaml
customresourcedefinition.apiextensions.k8s.io/tridentprovisioners.trident.netapp.io created

#OR

$ kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentprovisioners_crd_post1.16.yaml
customresourcedefinition.apiextensions.k8s.io/tridentprovisioners.trident.netapp.io created
```

You will end up with a brand new CRD:

```bash
$ kubectl get crd
NAME                                    CREATED AT
tridentprovisioners.trident.netapp.io   2020-05-06T08:48:08Z
```

We can now deploy the Operator, as well as all the necessary resources that go along with it:

```bash
$ kubectl create -f trident-installer/deploy/bundle.yaml
serviceaccount/trident-operator created
clusterrole.rbac.authorization.k8s.io/trident-operator created
clusterrolebinding.rbac.authorization.k8s.io/trident-operator created
deployment.apps/trident-operator created
podsecuritypolicy.policy/tridentoperatorpods created
```

Let's check what we currently have in the Trident namespace

```bash
$ kubectl get all -n trident
NAME                                   READY   STATUS    RESTARTS   AGE
pod/trident-csi-7ff4457f7d-bjhrt       4/4     Running   0          257d
pod/trident-csi-f4gdh                  2/2     Running   12         334d
pod/trident-csi-n4gtd                  2/2     Running   12         334d
pod/trident-operator-599794f56-pwzhd   1/1     Running   0          20s


NAME                  TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)     AGE
service/trident-csi   ClusterIP   10.97.78.31   <none>        34571/TCP   334d

NAME                         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                     AGE
daemonset.apps/trident-csi   2         2         2       2            2           kubernetes.io/arch=amd64,kubernetes.io/os=linux   334d

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trident-csi        1/1     1            1           334d
deployment.apps/trident-operator   1/1     1            1           20s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/trident-csi-7ff4457f7d       1         1         1       334d
replicaset.apps/trident-operator-599794f56   1         1         1       20s

```

OK, the operator is installed, as well as the provisioner CRD. Time to finally install the Trident provisioner:

```bash
$ kubectl create -f trident-installer/deploy/crds/tridentprovisioner_cr.yaml
tridentprovisioner.trident.netapp.io/trident created

$ kubectl get tprov -n trident
NAME      AGE
trident   13s
```

Tadaaaaa !  

Let's see the final content of the Trident namespace

```bash
$ kubectl get all -n trident
NAME                                   READY   STATUS    RESTARTS   AGE
pod/trident-csi-66d96cdcc4-5n5x9       4/4     Running   0          3m15s
pod/trident-csi-jwvfb                  2/2     Running   0          3m15s
pod/trident-csi-p929b                  2/2     Running   0          3m15s
pod/trident-csi-vs4nr                  2/2     Running   0          3m15s
pod/trident-operator-599794f56-pwzhd   1/1     Running   0          4m50s

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)              AGE
service/trident-csi   ClusterIP   10.109.36.143   <none>        34571/TCP,9220/TCP   3m16s

NAME                         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                                     AGE
daemonset.apps/trident-csi   3         3         3       3            3           kubernetes.io/arch=amd64,kubernetes.io/os=linux   3m15s

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trident-csi        1/1     1            1           3m15s
deployment.apps/trident-operator   1/1     1            1           4m50s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/trident-csi-66d96cdcc4       1         1         1       3m15s
replicaset.apps/trident-operator-599794f56   1         1         1       4m50s
```

One of the visible difference is that now Trident also installs a DaemonSet on the master node.

## D. Check the status

After a few seconds, you should the status _installed_ in the provisioner CRD.

```bash
$ kubectl describe tprov trident -n trident
Name:         trident
Namespace:    trident
Labels:       <none>
Annotations:  <none>
API Version:  trident.netapp.io/v1
Kind:         TridentProvisioner
Metadata:
  Creation Timestamp:  2020-08-26T14:53:43Z
  Generation:          1
  Resource Version:    587541
  Self Link:           /apis/trident.netapp.io/v1/namespaces/trident/tridentprovisioners/trident
  UID:                 5303a16d-db32-4d32-b759-99635649f3eb
Spec:
  Debug:  true
Status:
  Current Installation Params:
    IPv6:               false
    Autosupport Image:  netapp/trident-autosupport:20.07.0
    Autosupport Proxy:
    Debug:              true
    Image Pull Secrets:
    Image Registry:       quay.io
    k8sTimeout:           30
    Kubelet Dir:          /var/lib/kubelet
    Log Format:           text
    Silence Autosupport:  false
    Trident Image:        netapp/trident:20.07.0
  Message:                Trident installed
  Status:                 Installed
  Version:                v20.07.0
Events:
  Type    Reason      Age   From                        Message
  ----    ------      ----  ----                        -------
  Normal  Installing  29s   trident-operator.netapp.io  Installing Trident
  Normal  Installing  29s   trident-operator.netapp.io  A 'tridentctl-based' CSI Trident installation found in the namespace 'trident'; it will be replaced with an Operator-based Trident installation.
  Normal  Installing  29s   trident-operator.netapp.io  tridentctl-based CSI Trident installation removed.
  Normal  Installed   5s    trident-operator.netapp.io  Trident installed


$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 20.07.0        | 20.07.0        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   20.07.0
```

The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://netapp-trident.readthedocs.io/en/stable-v20.04/kubernetes/operator-install.html#observing-the-status-of-the-operator  
  
If you just want to display part of the description, you can use a filter such as:

```bash
$ kubectl describe tprov trident -n trident | grep Message: -A 3
  Message:  Trident installed
  Status:   Installed
  Version:  v20.07.0
```

## G. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)