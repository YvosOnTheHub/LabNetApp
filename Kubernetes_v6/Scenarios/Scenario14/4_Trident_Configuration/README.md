#########################################################################################
# SCENARIO 14.4: Trident configuration
#########################################################################################  

Now that the storage tenant is up & running, we can tell both Trident & Kubernetes to use it!  
```bash
$ kubectl create -n trident -f secret_ontap_nfs-secured.yaml
secret/ontap-nfs-secured-secret created

$ kubectl create -n trident -f backend-svm-secured-NFS.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-secured created

$ kubectl create -n trident -f secret_ontap_iscsi-secured.yaml
secret/ontap-iscsi-secured-secret created

$ kubectl create -n trident -f backend-svm-secured-iSCSI.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-san-secured created
```

Trident now has 2 new secured backends! Let's create some storage classes in Kubernetes:  
```bash
$ kubectl create -f sc-svm-secured-nas.yaml
storageclass.storage.k8s.io/sc-svm-secured-nas created

$ kubectl create -f sc-svm-secured-san.yaml
storageclass.storage.k8s.io/sc-svm-secured-san created

$ kubectl get sc
NAME                          PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-svm-secured-nas            csi.trident.netapp.io   Delete          Immediate           true                   39s
sc-svm-secured-san            csi.trident.netapp.io   Delete          Immediate           true                   31s
```

If you want a quick way to try out both new backends, you can use the following Ghost configurations:  
- _RWX File_ Ghost exposed on port 30980
- _RWO Block_ Ghost exposed on port 30981

```bash
$ kubectl create -f ghost-nas.yaml
namespace/ghost-nas-secured created
persistentvolumeclaim/blog-content created
deployment.apps/blog created
service/blog created

$ kubectl get -n ghost-nas-secured pod,pvc
NAME                        READY   STATUS    RESTARTS   AGE
pod/blog-7c4c5d59c4-s4c65   1/1     Running   0          2m8s

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS         VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/blog-content   Bound    pvc-3b8b8446-8b94-4531-942f-e5386cd6ca94   5Gi        RWX            sc-svm-secured-nas   <unset>                 2m8s

$ kubectl create -f ghost-san.yaml
namespace/ghost-san-secured created
persistentvolumeclaim/blog-content created
deployment.apps/blog created
service/blog created

$  kubectl get -n ghost-san-secured pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/blog-san-85c59d4cb-gxzqw   1/1     Running   0          2m12s

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS         VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/blog-content-san   Bound    pvc-15123451-e43a-4f3e-80e5-904cb9fca170   5Gi        RWO            sc-svm-secured-san   <unset>                 2m12s
```

& voilà, the POD are working with IPSec connectivity !

## What's next

You can now move on to:

- [Scenario15](../../Scenario15): CSI Topology Management

You can fo back to the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)