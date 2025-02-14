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

## B. Image management

The exercise will use the local private repository. If not done yet, we first need to pull the right Trident images, tag them & finally push them to _registry.demo.netapp.com_ (cf script *scenario01_pull_images.sh* in the Scenario01 folder):  
```bash
$ sh ../scenario01_pull_images.sh 
```

Also, this registry requires credentials to retrieve images. The linux nodes already have them saved locally, however the windows nodes do not have that information. Hence, we will create a secret so that the Trident operator can pull images locally:  
```bash
$ kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com
secret/regcred created
```

## C. Install the Trident operator

We first need to modify the image repository in the bundle provided in the 24.10 TGZ package downloaded earlier.  
Once done, you can apply this file to your environment.  
```bash
$ sed -i s,netapp\/,registry.demo.netapp.com\/, ~/24.10.0/trident-installer/deploy/bundle_post_1_25.yaml

$ kubectl create -f ~/24.10.0/trident-installer/deploy/bundle_post_1_25.yaml
serviceaccount/trident-operator created
clusterrole.rbac.authorization.k8s.io/trident-operator created
clusterrolebinding.rbac.authorization.k8s.io/trident-operator created
deployment.apps/trident-operator created
```
Then, you need to create a Trident Orchestrator, which is highly customizable.  
Several examples can be found in the _~/24.10.0/trident-installer/deploy/crds_ folder.  

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
  tridentImage: registry.demo.netapp.com/trident:24.10.0
  autosupportImage: registry.demo.netapp.com/trident-autosupport:24.10.0
  silenceAutosupport: true
  windows: true
  imagePullSecrets:
  - regcred
EOF
tridentorchestrator.trident.netapp.io/trident created
```

After a few minutes, you should see the following content of the Trident namespace:
```bash
$ kubectl get all -n trident
NAME                                      READY   STATUS    RESTARTS   AGE
pod/trident-controller-67dbfc9dfc-hnjcf   6/6     Running   0          2m24s
pod/trident-node-linux-9s4q5              2/2     Running   0          2m22s
pod/trident-node-linux-gm7qr              2/2     Running   0          2m22s
pod/trident-node-linux-jg6vr              2/2     Running   0          2m22s
pod/trident-node-windows-jnpmj            3/3     Running   0          2m21s
pod/trident-node-windows-tdxvl            3/3     Running   0          2m21s
pod/trident-operator-b577897b8-9tnq8      1/1     Running   0          5m30s

NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)              AGE
service/trident-csi   ClusterIP   10.96.34.221   <none>        34571/TCP,9220/TCP   2m28s

NAME                                  DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/trident-node-linux     3         3         3       3            3           <none>          2m22s
daemonset.apps/trident-node-windows   2         2         2       2            2           <none>          2m21s

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trident-controller   1/1     1            1           2m24s
deployment.apps/trident-operator     1/1     1            1           189d

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/trident-controller-67dbfc9dfc   1         1         1       2m24s
replicaset.apps/trident-operator-67d6fd899b     0         0         0       189d
replicaset.apps/trident-operator-b577897b8      1         1         1       5m30s
```

## D. Check the status

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
  Creation Timestamp:  2025-02-14T13:12:21Z
  Generation:          1
  Resource Version:    292691
  UID:                 8b97be12-9d04-4172-8fa7-9ae5c7e890dd
Spec:
  Autosupport Image:  registry.demo.netapp.com/trident-autosupport:24.10.0
  Debug:              true
  Image Pull Secrets:
    regcred
  Namespace:            trident
  Silence Autosupport:  true
  Trident Image:        registry.demo.netapp.com/trident:24.10.0
Status:
  Acp Version:  v24.10.0
  Current Installation Params:
    IPv6:                       false
    Acp Image:
    Autosupport Hostname:
    Autosupport Image:          registry.demo.netapp.com/trident-autosupport:24.10.0
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
      regcred
    Image Registry:
    Iscsi Self Healing Interval:   5m0s
    Iscsi Self Healing Wait Time:  7m0s
    k8sTimeout:                    30
    Kubelet Dir:                   /var/lib/kubelet
    Log Format:                    text
    Log Layers:
    Log Level:                     debug
    Log Workflows:
    Node Prep:                     <nil>
    Probe Port:                    17546
    Silence Autosupport:           true
    Trident Image:                 registry.demo.netapp.com/trident:24.10.0
  Message:                         Trident installed
  Namespace:                       trident
  Status:                          Installed
  Version:                         v24.10.0
Events:
  Type    Reason      Age    From                        Message
  ----    ------      ----   ----                        -------
  Normal  Installing  2m25s  trident-operator.netapp.io  Installing Trident
  Normal  Installed   108s   trident-operator.netapp.io  Trident installed

$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 24.10.0        | 24.10.0        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   24.10.0
```

The interesting part of this CRD is that you have access to the current status of Trident.
This is also where you are going to interact with Trident's deployment.  
If you want to know more about the different status, please have a look at the following link:  
https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy-operator.html#step-3-create-tridentorchestrator-and-install-trident
  
If you just want to display part of the description, you can use a filter such as:

```bash
$ kubectl describe torc trident | grep Message: -A 3
  Message:          Trident installed
  Namespace:        trident
  Status:           Installed
  Version:          v24.10.0
```

## E. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)