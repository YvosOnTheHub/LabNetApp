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

## D. What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?