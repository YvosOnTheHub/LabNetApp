#########################################################################################
# ADDENDA 0: Commands good to know
#########################################################################################

Here, I will bring you a few useful commands that you can use sometimes.  

## A. BASH

When you get more & more familiar with Kubernetes, you start wondering how to be more efficient in typing commands...
The first step would to put a bunch of alias in the .bashrc file

Some examples:

```bash
$ cat <<EOT >> ~/.bashrc
source <(kubectl completion bash)
complete -F __start_kubectl k

alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
```

Don't forget to type in _bash_ in order to take the modifications into account

## B. How can I easily list all the PVC of an application

If you are dealing with applications with lots of PODs & volumes, you may want to get a matrix which shows all the PVC per POD:
The following example was used in the Scenario12, which presents StatefulSets.

```bash
$ kubectl get pods -n mysql -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.volumes[*].persistentVolumeClaim}{.claimName}{" "}{end}{end}{"\n"}'
mysql-0:        data-mysql-0
mysql-1:        data-mysql-1
mysql-2:        data-mysql-2
```

## C. How can I easily list all the containers in a POD

As there is no option to do so, you need to _extract_ this information from the POD definition.
Here are some examples, in several Kubernetes versions

```bash
# 1.18 with Trident Operator (v20.07)
$ kubectl get pods -n trident -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' |sort
trident-csi-68d979fb85-dsrmn:   netapp/trident:20.07.1, netapp/trident-autosupport:20.07.0, quay.io/k8scsi/csi-provisioner:v2.0.1, quay.io/k8scsi/csi-attacher:v2.2.0, quay.io/k8scsi/csi-resizer:v0.5.0, quay.io/k8scsi/csi-snapshotter:v2.1.1,
trident-csi-8jfhf:      netapp/trident:20.07.1, quay.io/k8scsi/csi-node-driver-registrar:v1.3.0,
trident-csi-jtnjz:      netapp/trident:20.07.1, quay.io/k8scsi/csi-node-driver-registrar:v1.3.0,
trident-csi-lcxvh:      netapp/trident:20.07.1, quay.io/k8scsi/csi-node-driver-registrar:v1.3.0,
trident-operator-7569744d4f-hwgnr:      netapp/trident-operator:20.07.1,
```

What is interesting to notice is that when upgrading Kubernetes, new sidecars are added to CSI Trident:

- Kubernetes 1.16: Volume Expansion (CSI Resizer) was promoted to Beta status (cf https://kubernetes-csi.github.io/docs/volume-expansion.html)
- Kubernetes 1.17: Snapshot & Restore (CSI Snapshotter) was promoted to Beta status (cf https://kubernetes-csi.github.io/docs/snapshot-restore-feature.html)  

## D. How can I easily delete all PVC based on a filter

If you want to delete a large amount of PVC with one command, the easiest would be to put them all in one specific namespace.  
Once you delete this namespace, all its PVC will also go away.  

However, if you want to delete a few PVC based on a filter, you could use the following example, where I want to delete only the PVC containing the word _thick_:  

```bash
$ kubectl get pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
thick-5gb-1   Bound    pvc-58f21eea-a9a1-4007-ab95-411bcbc6755c   5Gi        RWX            sc-eco-thick   20s
thick-5gb-2   Bound    pvc-9dbd3f76-7979-488f-bdf2-de587499974d   5Gi        RWX            sc-eco-thick   20s
thick-5gb-3   Bound    pvc-f456b9b6-90b9-40bc-bd0e-2fed36d77056   5Gi        RWX            sc-eco-thick   20s
thin-5gb-1    Bound    pvc-1d2fe395-4e50-4cc7-979c-597e5c608a21   5Gi        RWX            sc-eco-thin    2m31s
thin-5gb-2    Bound    pvc-1b44405d-177f-4b12-8f7c-1816242f9a8e   5Gi        RWX            sc-eco-thin    2m31s
thin-5gb-3    Bound    pvc-fda63953-ef16-45b4-986b-99544abbbd09   5Gi        RWX            sc-eco-thin    2m31s

$ kubectl get pvc -o name | grep thick | xargs kubectl delete
persistentvolumeclaim "thick-5gb-1" deleted
persistentvolumeclaim "thick-5gb-2" deleted
persistentvolumeclaim "thick-5gb-3" deleted
```

## E. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?