#########################################################################################
# SCENARIO 27: Creating Virtual Machines
#########################################################################################

There are multiple ways to create your Virtual Machine.  
This all starts with the choice of base image to use. For this lab, let's use Alpine, a lightweight linux distribution, perfect for what we need. You can read more about Alpine on this link: https://www.alpinelinux.org/cloud/.  

We are going to use the _nocloud_ image, which allows cloud-init customization of the target VM via the injection of a script:  
```bash
mkdir -p ~/images && cd ~/images
wget https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/nocloud_alpine-3.22.1-x86_64-bios-tiny-r0.qcow2
```
There are multiple ways to put that image in a boot disk.  
One could decide to simply import the image in a PVC, easy and fast method.  
Others may prefer to add a DataVolume, abstraction layer that helps in creating Virtual Machine disks from multiple sources.    

A **DataVolume** is a CDI construct that helps you with the automation of the PVC creation (import VM image, clone volume, restore snapshot ...). The source of that DataVolume can be present in a registry, a HTTP url, an existing snapshot, etc...  

Note that DataVolume is also the volume keeper. If the underlying PVC were to be deleted, the DataVolume would automatcially recreate it. Of course, without a DataVolume, deleting a PVC is terminal.  

For all following chapters, we will use the same VM definition (*alpine_vm.yaml*).  
Some details about the content of this file:  
-  it contains a CloudInit part that will add extra configuration steps during the first boot, in our case, set the password for the alpine user, as well as creating a welcome message  
-  the network interface is of type *masquerade*

With masquerade binding, the VM’s network interface is NATed (Network Address Translated) behind the pod’s IP address.
- Outbound traffic from the VM is masqueraded (NATed) to appear as coming from the pod.
- Inbound traffic to the VM can be accessed via the pod’s IP and port-forwarding or Kubernetes Services.  


Now, let's jump in some methods to create a VM:  
- [Method1](./1_Method1/) import the image on a PVC  
- [Method2](./2_Method2/) import the image in a dataVolume from a registry  
- [Method3](./3_Method3/) import the image in a dataVolume with virtctl  
- [Method4](./4_Method4/) create a boot disk from a PVC clone  
- [Method5](./5_VM_Templates/) creating a catalogue of bootable disks  
