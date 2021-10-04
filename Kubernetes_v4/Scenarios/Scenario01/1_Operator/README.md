#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

**GOAL:**  
Starting with Trident 20.07, it is now possible to an Operator to upgrade from non-Operator based architectures.  
Before moving to the upgrade to Trident 21.07.2, we will first need to delete & clean up the current deployment.  

## A. Do some optional preparation work

Let's remove all current Kubernetes storage classes & Tridents' backends.

```bash
kubectl delete sc --all
tridentctl -n trident delete backend --all
```

## B. Upgrade Trident

Upgrading Trident first starts with creating a new CRD for the operator:

```bash
$ kubectl create -f trident-installer/deploy/crds/trident.netapp.io_tridentorchestrators_crd_post1.16.yaml
customresourcedefinition.apiextensions.k8s.io/tridentorchestrators.trident.netapp.io created
```

You can now delete a few objects related to the current version:

```bash
$ kubectl delete -f ~/20.07.1/trident-installer/deploy/bundle.yaml
serviceaccount "trident-operator" deleted
clusterrole.rbac.authorization.k8s.io "trident-operator" deleted
clusterrolebinding.rbac.authorization.k8s.io "trident-operator" deleted
deployment.apps "trident-operator" deleted
podsecuritypolicy.policy "tridentoperatorpods" deleted
```

We can finally deploy the Operator, as well as all the necessary resources that go along with it:

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
pod/trident-csi-66d96cdcc4-5n5x9       6/6     Running   0          3m15s
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

## C. Check the status

After a few seconds, you should the status _installed_ in the provisioner CRD.

```bash
$ kubectl describe torc -n trident
Name:         trident
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  trident.netapp.io/v1
Kind:         TridentOrchestrator
Metadata:
  Creation Timestamp:  2021-08-22T13:43:25Z
  Generation:          1
  Managed Fields:
    API Version:  trident.netapp.io/v1
    Manager:         trident-operator
    Operation:       Update
    Time:            2021-08-22T13:43:50Z
  Resource Version:  3524498
  Self Link:         /apis/trident.netapp.io/v1/tridentorchestrators/trident
  UID:               8384f117-9729-48cd-a2ee-36b08340f3f9
Spec:
  Debug:      false
  Namespace:  trident
Status:
  Current Installation Params:
    IPv6:                       false
    Autosupport Hostname:
    Autosupport Image:          netapp/trident-autosupport:21.01
    Autosupport Proxy:
    Autosupport Serial Number:
    Debug:                      false
    Enable Node Prep:           false
    Image Pull Secrets:
    Image Registry:
    k8sTimeout:           30
    Kubelet Dir:          /var/lib/kubelet
    Log Format:           text
    Probe Port:           17546
    Silence Autosupport:  false
    Trident Image:        netapp/trident:21.07.2
  Message:                Trident installed
  Namespace:              trident
  Status:                 Installed
  Version:                v21.07.2
Events:
  Type    Reason      Age    From                        Message
  ----    ------      ----   ----                        -------
  Normal  Installing  6m13s  trident-operator.netapp.io  Installing Trident
  Normal  Installed   5m53s  trident-operator.netapp.io  Trident installed



$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 21.07.2        | 21.07.2        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   21.07.2
```

The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://netapp-trident.readthedocs.io/en/stable-v21.04/kubernetes/deploying/operator-deploy.html#observing-the-status-of-the-operator
  
If you just want to display part of the description, you can use a filter such as:

```bash
$ kubectl describe torc trident -n trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  trident
  Status:     Installed
  Version:    v21.07.2
```

## D. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)