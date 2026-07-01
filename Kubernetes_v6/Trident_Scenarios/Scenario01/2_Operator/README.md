#########################################################################################
# SCENARIO 1: Trident installation with an Operator
#########################################################################################

By now, you should have cleaned up the environment. You can directly proceed with the Trident installation    

## A. Image management

The exercise will use the local private repository. If not done yet, we first need to pull the right Trident images, tag them & finally push them to _registry.demo.netapp.com_ (cf script *scenario01_pull_images.sh* in the Scenario01 folder):  
```bash
$ sh ../scenario01_pull_images.sh 
```

Also, this registry requires credentials to retrieve images. The linux nodes already have them saved locally, however the windows nodes do not have that information. Hence, we will create a secret so that the Trident operator can pull images locally:  
```bash
$ kubectl create ns trident
$ kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident --docker-server=registry.demo.netapp.com
secret/regcred created
```

## B. Install the Trident operator

We first need to modify the image repository in the bundle provided in the 26.06 TGZ package downloaded earlier.  
Once done, you can apply this file to your environment.  
```bash
$ sed -i s,docker.io\/netapp\/,registry.demo.netapp.com\/, ~/26.06.0/trident-installer/deploy/bundle.yaml

$ kubectl create -f ~/26.06.0/trident-installer/deploy/bundle.yaml
serviceaccount/trident-operator created
clusterrole.rbac.authorization.k8s.io/trident-operator created
clusterrolebinding.rbac.authorization.k8s.io/trident-operator created
deployment.apps/trident-operator created
```
Then, you need to create a Trident Orchestrator, which is highly customizable.  
Several examples can be found in the _~/26.06.0/trident-installer/deploy/crds_ folder.  

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
  tridentImage: registry.demo.netapp.com/trident:26.06.0
  autosupportImage: registry.demo.netapp.com/trident-autosupport:26.06.0
  silenceAutosupport: true
  windows: true
  imagePullSecrets:
  - regcred
EOF
tridentorchestrator.trident.netapp.io/trident created
```

After a few minutes, you should see the following content of the Trident namespace:
```bash
$ kubectl get po,svc -n trident
NAME                                      READY   STATUS    RESTARTS   AGE
pod/trident-controller-67dbfc9dfc-hnjcf   6/6     Running   0          2m24s
pod/trident-node-linux-9s4q5              2/2     Running   0          2m22s
pod/trident-node-linux-gm7qr              2/2     Running   0          2m22s
pod/trident-node-linux-jg6vr              2/2     Running   0          2m22s
pod/trident-node-windows-jnpmj            3/3     Running   0          2m21s
pod/trident-node-windows-tdxvl            3/3     Running   0          2m21s
pod/trident-operator-b577897b8-9tnq8      1/1     Running   0          5m30s

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                       AGE
service/trident-csi   ClusterIP   10.109.169.151   <none>        34571/TCP,9220/TCP,8444/TCP    2m28s
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
  Creation Timestamp:  2026-07-01T06:22:00Z
  Generation:          1
  Resource Version:    1217408
  UID:                 36fbc213-e34c-4eee-98cc-6e1defc0e69f
Spec:
  Autosupport Image:  registry.demo.netapp.com/trident-autosupport:26.06.0
  Debug:              true
  Image Pull Secrets:
    regcred
  Namespace:            trident
  Silence Autosupport:  true
  Trident Image:        registry.demo.netapp.com/trident:26.06.0
  Windows:              true
Status:
  Acp Version:  v26.06.0
  Current Installation Params:
    IPv6:                       false
    Acp Image:
    Autosupport Hostname:
    Autosupport Image:          registry.demo.netapp.com/trident-autosupport:26.06.0
    Autosupport Insecure:       false
    Autosupport Proxy:
    Autosupport Serial Number:
    Debug:                      true
    Disable Audit Log:          true
    Enable ACP:                 false
    Enable Concurrency:         false
    Enable Force Detach:        false
    Host Network:               false
    Http Request Timeout:       90s
    Https Metrics:              false
    Image Pull Policy:          IfNotPresent
    Image Pull Secrets:
      regcred
    Image Registry:
    Iscsi Self Healing Interval:   5m0s
    Iscsi Self Healing Wait Time:  7m0s
    k8sTimeout:                    180
    Kubelet Dir:                   /var/lib/kubelet
    Log Format:                    text
    Log Layers:
    Log Level:                     debug
    Log Workflows:
    Node Prep:                     <nil>
    Probe Port:                    17546
    Resources:
      Controller:
        Csi - Attacher:
          Requests:
            Cpu:     2m
            Memory:  20Mi
        Csi - Provisioner:
          Requests:
            Cpu:     2m
            Memory:  20Mi
        Csi - Resizer:
          Requests:
            Cpu:     3m
            Memory:  20Mi
        Csi - Snapshotter:
          Requests:
            Cpu:     2m
            Memory:  20Mi
        Trident - Autosupport:
          Requests:
            Cpu:     1m
            Memory:  30Mi
        Trident - Main:
          Requests:
            Cpu:     10m
            Memory:  80Mi
      Node:
        Linux:
          Node - Driver - Registrar:
            Requests:
              Cpu:     1m
              Memory:  10Mi
          Trident - Main:
            Requests:
              Cpu:     10m
              Memory:  60Mi
        Windows:
          Liveness - Probe:
            Requests:
              Cpu:     2m
              Memory:  40Mi
          Node - Driver - Registrar:
            Requests:
              Cpu:     6m
              Memory:  40Mi
          Trident - Main:
            Requests:
              Cpu:        10m
              Memory:     60Mi
    Silence Autosupport:  true
    Trident Image:        registry.demo.netapp.com/trident:26.06.0
  Message:                Trident installed
  Namespace:              trident
  Status:                 Installed
  Version:                v26.06.0
Events:
  Type    Reason      Age               From                        Message
  ----    ------      ----              ----                        -------
  Normal  Installing  2m10s             trident-operator.netapp.io  Installing Trident
  Normal  Installed   6s (x4 over 94s)  trident-operator.netapp.io  Trident installed


$ tridentctl -n trident version
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 26.06.0        | 26.06.0        |
+----------------+----------------+

$ kubectl -n trident get tridentversions
NAME      VERSION
trident   26.06.0
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
  Version:          v26.06.0
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

## D. What's next

Now that Trident is installed, you can proceed with :  

- [Scenario02](../../Scenario02):  Configure your first NAS backends & storage classes  
- [Scenario03](../../Scenario03):  Installing Prometheus & incorporate Trident's metrics  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)