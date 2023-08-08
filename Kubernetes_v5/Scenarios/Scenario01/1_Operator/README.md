#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

**GOAL:**  
The current environment comes with Trident manually installed as an Operator.  
Before moving to the upgrade to Trident 23.07.0, we will first clean up the current deployment.  

## A. Do some optional preparation work

Let's remove all current Kubernetes storage classes & Tridents' backends.

```bash
kubectl delete sc --all
tridentctl -n trident delete backend --all
```

## B. Upgrade Trident

Upgrading Trident first starts with deleting a few objects related to the current version (ie the _Trident Operator_):

```bash
$ kubectl delete -f ~/21.10.0/trident-installer/deploy/bundle.yaml
serviceaccount "trident-operator" deleted
clusterrole.rbac.authorization.k8s.io "trident-operator" deleted
clusterrolebinding.rbac.authorization.k8s.io "trident-operator" deleted
deployment.apps "trident-operator" deleted
podsecuritypolicy.policy "tridentoperatorpods" deleted
```

Let's modify the _Trident Orchestator_ to point the new installation to the private registry, as well as the _Trident Operator_ bundle:

```bash
$ kubectl -n netapp patch torc/trident --type=json -p='[ 
    {"op":"add", "path":"/spec/tridentImage", "value":"registry.demo.netapp.com/trident:23.07.0"}, 
    {"op":"add", "path":"/spec/autosupportImage", "value":"registry.demo.netapp.com/trident-autosupport:23.07.0"}
]'
tridentorchestrator.trident.netapp.io/trident patched

$ sed -i s,netapp\/,registry.demo.netapp.com\/, ~/23.07.0/trident-installer/deploy/bundle.yaml
```

We can finally deploy the Operator, as well as all the necessary resources that go along with it:

```bash
$ kubectl create -f ~/23.07.0/trident-installer/deploy/bundle.yaml
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
NAME                                      READY   STATUS    RESTARTS   AGE
pod/trident-controller-86f845bc69-zczfr   6/6     Running   0          9m29s
pod/trident-node-linux-7kmwp              2/2     Running   0          9m29s
pod/trident-node-linux-8xtfv              2/2     Running   0          9m29s
pod/trident-node-linux-djckp              2/2     Running   0          9m29s
pod/trident-operator-7748db54f5-w2pzg     1/1     Running   0          9m54s

NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)              AGE
service/trident-csi   ClusterIP   10.101.82.30   <none>        34571/TCP,9220/TCP   9m29s

NAME                                DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/trident-node-linux   3         3         3       3            3           <none>          9m29s

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trident-controller   1/1     1            1           9m29s
deployment.apps/trident-operator     1/1     1            1           9m54s

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/trident-controller-86f845bc69   1         1         1       9m29s
replicaset.apps/trident-operator-7748db54f5     1         1         1       9m54s
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
  Creation Timestamp:  2023-08-08T12:09:14Z
  Generation:          1
  Managed Fields:
    API Version:  trident.netapp.io/v1
    Fields Type:  FieldsV1
    Manager:      kubectl-create
    Operation:    Update
    Time:         2021-12-01T02:05:17Z
    API Version:  trident.netapp.io/v1
    Fields Type:  FieldsV1
    Manager:      kubectl-patch
    Operation:    Update
    Time:         2022-11-20T17:59:19Z
    API Version:  trident.netapp.io/v1
    Manager:         trident-operator
    Operation:       Update
    Subresource:     status
    Time:            2022-11-20T18:02:02Z
  Resource Version:  20028639
  UID:               331ae347-8f9a-4f3d-b195-3939e0c16c6c
Spec:
  Autosupport Image:  registry.demo.netapp.com/trident-autosupport:23.07.0
  Debug:              false
  Namespace:          trident
  Trident Image:      registry.demo.netapp.com/trident:23.07.0
Status:
  Current Installation Params:
    IPv6:                       false
    Autosupport Hostname:
    Autosupport Image:          registry.demo.netapp.com/trident-autosupport:23.07.0
    Autosupport Proxy:
    Autosupport Serial Number:
    Debug:                      false
    Http Request Timeout:       90s
    Image Pull Secrets:
    Image Registry:
    k8sTimeout:           30
    Kubelet Dir:          /var/lib/kubelet
    Log Format:           text
    Probe Port:           17546
    Silence Autosupport:  false
    Trident Image:        registry.demo.netapp.com/trident:23.07.0
  Message:                Trident installed
  Namespace:              trident
  Status:                 Installed
  Version:                v23.07.0
Events:
  Type    Reason     Age   From                        Message
  ----    ------     ----  ----                        -------
  Normal  Installed  12m   trident-operator.netapp.io  Trident installed

$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 23.07.0        | 23.07.0        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   23.07.0
```

The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-operator.html#step-3-create-tridentorchestrator-and-install-trident
  
If you just want to display part of the description, you can use a filter such as:

```bash
$ kubectl describe torc trident -n trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  trident
  Status:     Installed
  Version:    v23.07.0
```

## D. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)