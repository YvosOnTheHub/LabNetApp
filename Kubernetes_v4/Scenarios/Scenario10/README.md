#########################################################################################
# SCENARIO 10: Working with Virtual Storage Pools
#########################################################################################

**GOAL:**  
While creating a backend, you can generally specify a set of parameters. It was impossible for the administrator to create another backend with the same storage credentials and with a different set of parameters. With the introduction of Virtual Storage Pools, this issue has been alleviated. Virtual Storage Pools is a level of abstraction introduced between the backend and the Kubernetes Storage Class so that the administrator can define parameters along with labels which can be referenced through Kubernetes Storage Classes as a selector, in a backend-agnostic way.  

The following parameters can be used in the Virtual Pools:

- spaceAllocation
- spaceReserve
- snapshotPolicy
- snapshotReserve
- encryption
- unixPermissions
- snapshotDir
- exportPolicy
- securityStyle
- tieringPolicy

In this lab, instead of creating a few backends pointing to the same SVM, we are going to use Virtual Storage Pools

<p align="center"><img src="Images/scenario10.jpg"></p>

If you have not yet read the [Addenda09](../../Addendum/Addenda09) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario10_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario10_pull_images.sh my_login my_password
```

## A. Create the new backend

If you take a look at the backend definition, you will see that there are 3 Virtual Storage Pools.
Each one with a different set of parameters.

```bash
$ tridentctl -n trident create backend -f backend_nas_vsp.json
+---------+----------------+--------------------------------------+--------+---------+
|  NAME   | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+---------+----------------+--------------------------------------+--------+---------+
| NAS_VSP | ontap-nas      | 6cb114a6-1b48-45ee-9ea4-f4267e0e4498 | online |       0 |
+---------+----------------+--------------------------------------+--------+---------+
```

## B. Create new storage classes.

We are going to create 3 storage classes, one per Virtual Storage Pool.

```bash
$ kubectl create -f sc-vsp1.yaml
storageclass.storage.k8s.io/sc-vsp1 created
$ kubectl create -f sc-vsp2.yaml
storageclass.storage.k8s.io/sc-vsp2 created
$ kubectl create -f sc-vsp3.yaml
storageclass.storage.k8s.io/sc-vsp3 created

$ kubectl get sc -l scenario=vsp
NAME                        PROVISIONER             AGE
sc-vsp1                     csi.trident.netapp.io   46h
sc-vsp2                     csi.trident.netapp.io   46h
sc-vsp3                     csi.trident.netapp.io   46h
```

## C. Create a few PVC & a POD in their own namespace

Each of the 3 PVC will point to a different Storage Class.  

```bash
$ kubectl create namespace vsp
namespace/vsp created
$ kubectl create -n vsp -f pvc1.yaml
persistentvolumeclaim/pvc-vsp-1 created
$ kubectl create -n vsp  -f pvc2.yaml
persistentvolumeclaim/pvc-vsp-2 created
$ kubectl create -n vsp  -f pvc3.yaml
persistentvolumeclaim/pvc-vsp-3 created

$ kubectl get -n vsp pvc,pv
NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/pvc-vsp-1   Bound    pvc-45169dd9-c9b3-47bf-815a-319bc8d42c69   1Gi        RWX            sc-vsp1        46h
persistentvolumeclaim/pvc-vsp-2   Bound    pvc-3020f487-414d-4396-a0a2-aedd982896c5   1Gi        RWX            sc-vsp2        46h
persistentvolumeclaim/pvc-vsp-3   Bound    pvc-0111127b-e1be-45fb-992d-b97108f55284   1Gi        RWX            sc-vsp3        46h

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM               STORAGECLASS   REASON   AGE
persistentvolume/pvc-0111127b-e1be-45fb-992d-b97108f55284   1Gi        RWX            Delete           Bound    vsp/pvc-vsp-3       sc-vsp3                 46h
persistentvolume/pvc-3020f487-414d-4396-a0a2-aedd982896c5   1Gi        RWX            Delete           Bound    vsp/pvc-vsp-2       sc-vsp2                 46h
persistentvolume/pvc-45169dd9-c9b3-47bf-815a-319bc8d42c69   1Gi        RWX            Delete           Bound    vsp/pvc-vsp-1       sc-vsp1                 46h
```

The POD we are going to use will mount all 3 PVC. We will then check the differences.
Pay attention to the rights set in the Virtual Storage Pools json file.

```bash
$ kubectl create -n vsp -f pod-centos-nas.yaml
pod/centos created
$ kubectl -n vsp get pod
NAME     READY   STATUS    RESTARTS   AGE
centos   1/1     Running   0          13s
```

Let's check!

```bash
$ kubectl -n vsp exec centos -- ls -hl /data
total 12K
drwxr--r-- 2 root root 4.0K Apr  3 16:26 pvc1
drwxrwxrwx 2 root root 4.0K Apr  3 16:34 pvc2
drwxr-xr-x 2 root root 4.0K Apr  3 16:34 pvc3
```

As planned, you can see here the correct permissions:

- PVC1: **744** (parameter for the VSP _myapp1_)
- PVC2: **777** (parameter for the VSP _myapp2_)
- PVC3: **755** (default parameter for the backend)  

Also, some PVC have the snapshot directory visible, some don't.

```bash
$ kubectl -n vsp exec centos -- ls -hla /data/pvc2
total 8.0K
drwxrwxrwx 2 root root 4.0K Apr  3 16:34 .
drwxr-xr-x 5 root root   42 Apr  5 14:45 ..
drwxrwxrwx 2 root root 4.0K Apr  3 16:34 .snapshot

$ kubectl -n vsp exec centos -- ls -hla /data/pvc3
total 4.0K
drwxr-xr-x 2 root root 4.0K Apr  3 16:34 .
drwxr-xr-x 5 root root   42 Apr  5 14:45 ..
```

**Conclusion:**  
This could have all be done through 3 different backend files, which is also perfectly fine.
However, the more backends you manage, the more complexity you add. Introducing Virtual Storage Polls allows you to simplify this management.

## C. Label Management

Trident 21.01.1 introduced label management at the backend layer. If you configure labels in a Trident Backend, they will be added to the volume comments field.  
Let's check how that translates with the first PVC we have created (Storage Pool with labels {"app":"myapp1", "cost":"100"}):  

```bash
$ VOLNAME=$(kubectl get pv $( kubectl get pvc pvc-vsp-1 -n vsp -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.spec.csi.volumeAttributes.internalName}') && curl -X GET -ku vsadmin:Netapp1!  "https://192.168.0.135/api/storage/volumes?name=$VOLNAME&fields=comment" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "e353b98d-71ed-11eb-9619-0050569c2f0a",
      "comment": "{\"provisioning\":{\"app\":\"myapp1\",\"cost\":\"100\"}}",
      "name": "vsp_pvc_85fbfc56_2b91_41e0_8cd5_592cf6ce9c13"
    }
  ],
  "num_records": 1
}
```

There you go, the two labels can be seen in the comments field!

## D. Cleanup the environment

```bash
$ kubectl delete namespace vsp
namespace "resize" deleted

$ kubectl delete sc -l scenario=vsp
storageclass.storage.k8s.io "sc-vsp1" deleted
storageclass.storage.k8s.io "sc-vsp2" deleted
storageclass.storage.k8s.io "sc-vsp3" deleted

$ tridentctl -n trident delete backend NAS_VSP
```

## D. What's next

You can now move on to:

- [Scenario11](../Scenario11): StatefulSets & Storage consumption  
- [Scenario13](../Scenario13): Dynamic export policy management  
- [Scenario14](../Scenario14): On-Demand Snapshots & Create PVC from Snapshot  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)
