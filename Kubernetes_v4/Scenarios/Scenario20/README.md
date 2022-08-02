#########################################################################################
# SCENARIO 20: About Generic Ephemeral Volumes
#########################################################################################

When talking about Trident, we often refer to Persistent Volumes. It is indeed the most common use of such CSI driver. There are multiple benefits of using persistent volumes, one of them being that the volumes remains after the application is gone (ya, that is actually why it is called _persistent_).  

For some use cases, you may need a volume for your application to store files that are absolutely not important & can be deleted alongside the application when you dont need it anymore. That is where Ephemeral Volumes could be useful.

Kubernetes proposes different types of ephemeral volumes:

- emptyDir
- configMap
- CSI ephemeral volumes (_not supported by Trident_)
- **generic ephemeral volumes** (_supported by Trident_)

This chapter focuses on the last category which was introduced as an alpha feature in Kubernetes 1.19 (Beta in K8S 1.21 & GA in K8S 1.23).  
Please refer to [Addenda14](../../Addendum/Addenda14) in order to upgrade this environment.  
We consider that the ONTAP-NAS backend & storage class have already been created. ([cf Scenario02](../Scenario02)).  

The construct of a POD manifest with Generic Ephemeral Volumes is pretty similar to what you would see with StatefulSets, ie the volume definition is included in the POD object. This folder contains a simple busybox pod manifest. You will see that :

- a volume is created alongside the POD that will mount it
- when the POD is deleted, the volume follows the same path & disappears

```bash
$ kubectl create -f my-app.yaml
pod/my-app created

$ kubectl get pod,pvc
NAME         READY   STATUS    RESTARTS   AGE
pod/my-app   1/1     Running   0          17s

NAME                                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
persistentvolumeclaim/my-app-scratch-volume   Bound    pvc-e018e7ab-a95b-4cb7-a366-85953d8fdec5   1Gi        RWO            storage-class-nas   17s

$ kubectl exec my-app -- df -h /scratch
Filesystem                Size      Used Available Use% Mounted on
192.168.0.135:/nas1_pvc_e018e7ab_a95b_4cb7_a366_85953d8fdec5
                          1.0G    256.0K   1023.8M   0% /scratch

$ kubectl delete -f gev.yaml
pod "my-app" deleted

$ kubectl get pod,pvc
No resources found in default namespace.
```

Note that creating this kind of pod does not display a _pvc created_ message.  

## What's next

You can go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)