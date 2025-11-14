#########################################################################################
# SCENARIO 27: Creating a catalogue of bootable images
#########################################################################################

With what we learned in the previous chapters of this Scenario, let's create a catalogue of Virtual Machines bootable disks!  

## A. Chapter requirements

Let's start by creating a namespace for that purpose:  
```bash
$ kubectl create ns vm-templates
namespace/vm-templates created
```

We will follow the [Method2](../2_Method2/) to provision volumes.  
If not done yet, make sure you have pushed an Alpine image on the lab registry.  

Last, make sure there is a _Volume Snapshot Class_ available.  
```bash
$ kubectl get vsclass
NAME             DRIVER                  DELETIONPOLICY   AGE
csi-snap-class   csi.trident.netapp.io   Delete           20h
```
If not present, you can use the following to create one:  
```bash
$ kubectl create -f ../../../Scenario13/1_CSI_Snapshots/sc-volumesnapshot.yaml
volumesnapshotclass.snapshot.storage.k8s.io/csi-snap-class created
```

## B. Templates creation

Let's create two templates with the following method:  
- create a secret containing the registry credentials  
- create a DataVolume based on Alpine Linux 
- create a Virtual Machine with a CloudInit customization  
- delete the Virtual Machine

Let's begin with the 2 DataVolumes:  
```bash
$ kubectl create -f registry_secret.yaml -f tmpl1_dv.yaml -f tmpl2_dv.yaml
secret/endpoint-secret
datavolume.cdi.kubevirt.io/alpine-tmpl1 created
datavolume.cdi.kubevirt.io/alpine-tmpl2 created
```
At this point, both volumes should be ready:  
```bash
$ kubectl get -n vm-templates all,pvc
NAME                                      PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-tmpl1   Succeeded   100.0%                3m23s
datavolume.cdi.kubevirt.io/alpine-tmpl2   Succeeded   100.0%                3m23s

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-tmpl1   Bound    pvc-cdecfc64-31c6-423e-a592-bf2a772f1cbd   1Gi        RWX            storage-class-iscsi   <unset>                 3m22s
persistentvolumeclaim/alpine-tmpl2   Bound    pvc-bbacebc0-a8e1-4fe2-ac4c-6a20f28b094f   1Gi        RWX            storage-class-iscsi   <unset>                 3m22s
```
Time to deploy our Virtual Machine templates. For this exercise, the only difference will be in the "Message of the day" file.  
Of course, you could go quite far in the customization of your boot images...  
```bash
$ kubectl create -f vm1.yaml -f vm2.yaml
virtualmachine.kubevirt.io/alpine-tmpl1 created
virtualmachine.kubevirt.io/alpine-tmpl2 created
```
We now have 2 Virtual Machines available:  
```bash
$ kubectl get -n vm-templates vm
NAME           AGE     STATUS    READY
alpine-tmpl1   2m25s   Running   True
alpine-tmpl2   2m25s   Running   True
```
Connect to the VMs to see that the init process was correctly executed.  
Example with the second VM:  
```bash
$ virtctl console -n vm-templates alpine-tmpl2
Successfully connected to alpine-tmpl2 console. Press Ctrl+] or Ctrl+5 to exit console.

Welcome to Alpine Linux 3.22
Kernel 6.12.38-0-virt on x86_64 (/dev/ttyS0)

alpine-tmpl2.vm-templates.svc.cluster.local login: alpine
Password:
This is the second template
```
Your templates are now ready, you can stop and delete the VMs, while keeping the boot disks:  
```bash
$ virtctl stop -n vm-templates alpine-tmpl1
VM alpine-tmpl1 was scheduled to stop

$ virtctl stop -n vm-templates alpine-tmpl2
VM alpine-tmpl2 was scheduled to stop

$ kubectl delete -n vm-templates vm --all
virtualmachine.kubevirt.io "alpine-tmpl1" deleted
virtualmachine.kubevirt.io "alpine-tmpl2" deleted
```

## C. Creating a VM from a template

A new user comes on the platform and would like to start a VM based on the second snapshot.  
Let's start by creating a new namespace:  
```bash
$ kubectl create ns my-alpine
namespace/my-alpine created
```
Creating our VM from the catalogue of boot disks is done in 2 steps in this example:  
- creation of a DataVolume  
- creation of the Virtual Machine

You could very well manage everything at once, by including a DataVolumeTemplate in the VM definition.  
However, this is not covered here.

```bash
$ kubectl create -f vm1_dv.yaml
datavolume.cdi.kubevirt.io/alpine-boot created

$ kubectl get -n my-alpine all,pvc
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                     PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot   Succeeded   100.0%                23s

NAME                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot   Bound    pvc-4f94b1a4-e150-4e51-be46-bd7473347a3c   1Gi        RWX            storage-class-iscsi   <unset>                 23s

$ kubectl create -f vm1_vm.yaml
virtualmachine.kubevirt.io/alpine-vm created

$ kubectl get vm -n my-alpine
NAME        AGE   STATUS    READY
alpine-vm   44s   Running   True
```
Seems like everything is running! Let's connect to the VM to validate we have the correct content:  
```bash
$ virtctl console -n my-alpine alpine-vm
Successfully connected to alpine-vm console. Press Ctrl+] or Ctrl+5 to exit console.

Welcome to Alpine Linux 3.22
Kernel 6.12.38-0-virt on x86_64 (/dev/ttyS0)

alpine-vm.my-alpine.svc.cluster.local login: alpine
Password:
This is the second template
```
And voilà, you have successfully created a catalogue of customized bootable disks!