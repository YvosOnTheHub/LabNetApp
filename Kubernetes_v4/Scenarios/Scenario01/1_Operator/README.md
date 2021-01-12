#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

**GOAL:**  
Starting with Trident 20.07, it is now possible to an Operator to upgrade from non-Operator based architectures.  
Before moving to the upgrade to Trident 20.10, we will first need to delete & clean up the current deployment.  

## A. Download the new version & do some preparation work

First, let's remove all current Kubernetes storage classes & Tridents' backends (this is optional)

```bash
kubectl delete sc --all
tridentctl -n trident delete backend --all
```

Download the version you would like to install

```bash
cd
mv trident-installer/ trident-installer_20.07
wget https://github.com/NetApp/trident/releases/download/v20.10.0/trident-installer-20.10.0.tar.gz
tar -xf trident-installer-20.10.0.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/
```

:mag:  
*A* **resource** *is an endpoint in the Kubernetes API that stores a collection of API objects of a certain kind; for example, the built-in pods resource contains a collection of Pod objects.*  
*A* **custom resource** *is an extension of the Kubernetes API that is not necessarily available in a default Kubernetes installation. It represents a customization of a particular Kubernetes installation. However, many core Kubernetes functions are now built using custom resources, making Kubernetes more modular.*  
:mag_right:  

Trident 20.10 introduced the support of the **CSI Topology** feature which allows the administrator to manage a location aware infrastructure.  
However, there are 2 requirements for this to work:

- You need at least Kubernetes 1.17 (:heavy_check_mark:!)  
- Somes labels (region & zone) need to be added to the Kubernetes nodes before Trident is installed.

If you are planning on testing this feature (cf [Scenario16](../../Scenario16)), make sure these labels are configured before upgrading Trident.  

```bash
$ kubectl get nodes -o=jsonpath='{range .items[*]}[{.metadata.name}, {.metadata.labels}]{"\n"}{end}' | grep "topology.kubernetes.io"
[rhel1, map[beta.kubernetes.io/arch:amd64 beta.kubernetes.io/os:linux kubernetes.io/arch:amd64 kubernetes.io/hostname:rhel1 kubernetes.io/os:linux topology.kubernetes.io/region:trident topology.kubernetes.io/zone:west]]
[rhel2, map[beta.kubernetes.io/arch:amd64 beta.kubernetes.io/os:linux kubernetes.io/arch:amd64 kubernetes.io/hostname:rhel2 kubernetes.io/os:linux topology.kubernetes.io/region:trident topology.kubernetes.io/zone:east]]
[rhel3, map[beta.kubernetes.io/arch:amd64 beta.kubernetes.io/os:linux kubernetes.io/arch:amd64 kubernetes.io/hostname:rhel3 kubernetes.io/os:linux node-role.kubernetes.io/master: topology.kubernetes.io/region:trident topology.kubernetes.io/zone:admin]]
```

If they are not, you can create them with the following commands:

```bash
# LABEL "REGION"
kubectl label node rhel1 "topology.kubernetes.io/region=trident"
kubectl label node rhel2 "topology.kubernetes.io/region=trident"
kubectl label node rhel3 "topology.kubernetes.io/region=trident"

# LABEL "ZONE"
kubectl label node rhel1 "topology.kubernetes.io/zone=west"
kubectl label node rhel2 "topology.kubernetes.io/zone=east"
kubectl label node rhel3 "topology.kubernetes.io/zone=admin"
```

Last, if you have not yet read the [Addenda09](../../../Addendum/Addenda09) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario01_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario01_pull_images.sh my_login my_password
```


You can now upgrade Trident :trident:  

## C. Upgrade Trident

Upgrading Trident first starts with deleting a few objects:

```bash
$ kubectl delete -f trident-installer/deploy/bundle.yaml
serviceaccount "trident-operator" deleted
clusterrole.rbac.authorization.k8s.io "trident-operator" deleted
clusterrolebinding.rbac.authorization.k8s.io "trident-operator" deleted
deployment.apps "trident-operator" deleted
podsecuritypolicy.policy "tridentoperatorpods" deleted
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

Tadaaaaa !  
Pretty easy, right ?!  

Give it 30 seconds, & then let's see the final content of the Trident namespace

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
  ...
Spec:
  Debug:  false
  Silence Autosupport:  false
Status:
  Current Installation Params:
    IPv6:               false
    Autosupport Hostname:
    Autosupport Image:  netapp/trident-autosupport:20.10.0
    Autosupport Proxy:
    Autosupport Serial Number:
    Debug:              false
    Enable Node Prep:   false
    Image Pull Secrets:
    Image Registry:       quay.io
    k8sTimeout:           30
    Kubelet Dir:          /var/lib/kubelet
    Log Format:           text
    Silence Autosupport:  false
    Trident Image:        netapp/trident:20.10.0
  Message:                Trident installed
  Status:                 Installed
  Version:                v20.10.0
Events:
  Type    Reason      Age   From                        Message
  ----    ------      ----  ----                        -------
  Normal  Installed  2m30s (x16 over 67m)  trident-operator.netapp.io  Trident installed
  Normal  Installed  3s (x4 over 25s)      trident-operator.netapp.io  Trident installed


$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 20.10.0        | 20.10.0        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   20.10.0
```

The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://netapp-trident.readthedocs.io/en/stable-v20.10/kubernetes/deploying/operator-deploy.html#observing-the-status-of-the-operator  
  
If you just want to display part of the description, you can use a filter such as:

```bash
$ kubectl describe tprov trident -n trident | grep Message: -A 3
  Message:  Trident installed
  Status:   Installed
  Version:  v20.10.0
```

## G. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)