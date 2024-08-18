#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

**GOAL:**  
The current environment comes with Trident installed with the Helm chart.  
We will here first remove the helm chart in order to manually install the operator.    

## A. Remove Trident 24.02

Removing an application deployed with Helm is pretty straight forward:  
```bash
helm uninstall trident -n trident
```
Note that some objects are left behind, such as trident namespace as well as all the Trident CRD.   

## B. Install the Trident operator

We first need to modify the image repository in the bundle provided in the 24.06 TGZ package downloaded earlier.  
Once done, you can apply this file to your environment.  
```bash
$ sed -i s,netapp\/,registry.demo.netapp.com\/, ~/24.06.1/trident-installer/deploy/bundle_post_1_25.yaml

$ kubectl create -f ~/24.06.1/trident-installer/deploy/bundle_post_1_25.yaml
serviceaccount/trident-operator created
clusterrole.rbac.authorization.k8s.io/trident-operator created
clusterrolebinding.rbac.authorization.k8s.io/trident-operator created
deployment.apps/trident-operator created
```
Then, you need to create a Trident Orchestrator, which is highly customizable.  
Several examples can be found in the _~/24.06.1/trident-installer/deploy/crds_ folder.  

Let's create our own:
```bash
$ cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentOrchestrator
metadata:
  name: trident
spec:
  debug: true
  namespace: trident
  tridentImage: registry.demo.netapp.com/trident:24.06.1
  autosupportImage: registry.demo.netapp.com/trident-autosupport:24.06.0
  silenceAutosupport: true
EOF
tridentorchestrator.trident.netapp.io/trident created
```

After a few seconds, you should see the following content of the Trident namespace:
```bash
$ kubectl get all -n trident
NAME                                      READY   STATUS    RESTARTS       AGE
pod/trident-controller-65f99787f5-b9hz6   6/6     Running   0              6m37s
pod/trident-node-linux-h97kr              2/2     Running   1 (6m5s ago)   6m36s
pod/trident-node-linux-vsv9g              2/2     Running   0              6m36s
pod/trident-node-linux-vv9r4              2/2     Running   0              6m36s
pod/trident-operator-dcd9d7f8-9d8rj       1/1     Running   0              3h26m

NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)              AGE
service/trident-csi   ClusterIP   10.104.13.85   <none>        34571/TCP,9220/TCP   6m43s

NAME                                DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/trident-node-linux   3         3         3       3            3           <none>          6m36s

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trident-controller   1/1     1            1           6m38s
deployment.apps/trident-operator     1/1     1            1           3h26m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/trident-controller-65f99787f5   1         1         1       6m37s
replicaset.apps/trident-operator-dcd9d7f8       1         1         1       3h26m
```

## C. Check the status

After a few seconds, you should the status _installed_ in the orchestrator CR.  
```bash
$ kubectl describe torc
Name:         trident
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  trident.netapp.io/v1
Kind:         TridentOrchestrator
Metadata:
  Creation Timestamp:  2024-07-10T13:51:27Z
  Generation:          1
  Resource Version:    366529
  UID:                 4bfa93d4-6a28-4633-88a3-698cf5b044db
Spec:
  Autosupport Image:    registry.demo.netapp.com/trident-autosupport:24.06.0
  Debug:                true
  Namespace:            trident
  Silence Autosupport:  true
  Trident Image:        registry.demo.netapp.com/trident:24.06.0
  Windows:              false
Status:
  Current Installation Params:
    IPv6:                       false
    Acp Image:                  cr.astra.netapp.io/astra/trident-acp:24.06.0
    Autosupport Hostname:
    Autosupport Image:          registry.demo.netapp.com/trident-autosupport:24.06.0
    Autosupport Insecure:       false
    Autosupport Proxy:
    Autosupport Serial Number:
    Debug:                      true
    Disable Audit Log:          true
    Enable ACP:                 false
    Enable Force Detach:        false
    Http Request Timeout:       90s
    Image Pull Policy:          IfNotPresent
    Image Pull Secrets:
    Image Registry:
    Iscsi Self Healing Interval:   5m0s
    Iscsi Self Healing Wait Time:  7m0s
    k8sTimeout:                    30
    Kubelet Dir:                   /var/lib/kubelet
    Log Format:                    text
    Log Layers:
    Log Level:                     debug
    Log Workflows:
    Probe Port:                    17546
    Silence Autosupport:           true
    Trident Image:                 registry.demo.netapp.com/trident:24.06.0
  Message:                         Trident installed
  Namespace:                       trident
  Status:                          Installed
  Version:                         v24.06.0
Events:
  Type    Reason      Age   From                        Message
  ----    ------      ----  ----                        -------
  Normal  Installing  11m   trident-operator.netapp.io  Installing Trident
  Normal  Installed   10m   trident-operator.netapp.io  Trident installed

$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 24.06.0        | 24.06.0        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   24.06.0
```

The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-operator.html#step-3-create-tridentorchestrator-and-install-trident
  
If you just want to display part of the description, you can use a filter such as:

```bash
$ kubectl describe torc trident | grep Message: -A 3
  Message:    Trident installed
  Namespace:  
  Status:     Installed
  Version:    v24.06.0
```

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>    

There is currently an issue with Trident & the Windows nodes.  
You can notice that both Trident windows pods are in a _ImagePullBackOff/CrashLoopBAckOff_ status.  
This is because the nodes cannot authenticate to the private registry.  

In order for the installation to complete you MUST run the following on both windows hosts in order to manually pull the Trident image:  
```bash
crictl pull --creds registryuser:Netapp1! registry.demo.netapp.com/trident:24.06.1
```

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>  


## D. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)