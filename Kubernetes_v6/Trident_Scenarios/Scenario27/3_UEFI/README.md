#########################################################################################
# SCENARIO 27: EFI Virtual Machines
#########################################################################################

In all other scenarios, a BIOS based image was used to create virtual machines.  
What about EFI based images, can they also mount the same type of disks? Do they also support Live Migration?

**TL;DR START**  
Both BIOS or UEFI (with or without SecureBoot) based images support LiveMigration with RWX PVC with volumeMode Block!  
**TL;DR STOP**

First, here is information comparing both modes:  

Traditional BIOS and EFI (usually called UEFI today) are two different firmware systems that start a machine before the OS kernel runs.

BIOS boot, simplified:
1. Firmware does basic hardware init.
2. It looks for boot code in the disk’s first sector (MBR).
3. That tiny boot code loads the next-stage bootloader.
4. Bootloader loads the OS kernel.

UEFI boot, simplified:
1. Firmware does hardware init with a richer firmware environment.
2. It reads boot entries from NVRAM.
3. It loads an EFI executable from the EFI System Partition (ESP), for example BOOTX64.EFI.
4. That EFI bootloader loads the OS kernel.

In short: BIOS boots from disk sectors; UEFI boots EFI files from a dedicated partition with a richer, modern boot framework. UEFI can also be used to enforce signed boot chain with Secure Boot.  

## A. Alpine UEFI Virtual Machine

Let's start with a simple Alpine VM, which will be booted usng UEFI.  
As this uses a different image compared to previous scenarios, we first need to download the right QCow2 file:  
```bash
mkdir -p ~/images
wget -P ~/images https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/cloud/generic_alpine-3.24.1-x86_64-uefi-tiny-r0.qcow2
```
Next, we can create the DataVolume (*alpine_uefi_dv.yaml*) that will manage the PVC onto which we will upload the image:
```bash
$ kubectl create ns uefi
namespace/uefi created

$ kubectl create -f alpine_uefi_dv.yaml
datavolume.cdi.kubevirt.io/alpine-uefi-boot created

$ kubectl get -n uefi dv,pvc
NAME                                          PHASE         PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-uefi-boot   UploadReady   N/A                   24s

NAME                                                                       STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                  VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-uefi-boot                                     Pending                                                                        storage-class-iscsi           <unset>                 24s
persistentvolumeclaim/prime-b006aa0c-f4cb-4d81-8da7-00e266b6a565           Bound     pvc-98eb29f8-b534-4b79-aba8-12e8ea227247   1Gi        RWX            storage-class-iscsi           <unset>                 24s
persistentvolumeclaim/prime-b006aa0c-f4cb-4d81-8da7-00e266b6a565-scratch   Bound     pvc-8183b984-5baf-4e4a-809b-294cf5d77e4b   1086Mi     RWO            storage-class-iscsi-economy   <unset>                 23s
```
As we specified *upload* for the source disk, the DataVolume is not waiting for us to provide an image:  
```bash
$ virtctl image-upload dv alpine-uefi-boot \
  --namespace uefi \
  --image-path=/root/images/generic_alpine-3.24.1-x86_64-uefi-tiny-r0.qcow2 \
  --size=1Gi \
  --insecure \
  --uploadproxy-url=https://192.168.0.212:443
Using existing PVC uefi/prime-484d8797-247f-4246-a3bc-38e64162856b
Uploading data to https://192.168.0.212:443

129.44 MiB / 129.44 MiB [---------------------------------------------------------------------------------------------------------------] 100.00% 132.97 MiB p/s 1.2s

Uploading data completed successfully, waiting for processing to complete, you can hit ctrl-c without interrupting the progress
Processing completed successfully
Uploading /root/images/generic_alpine-3.24.1-x86_64-uefi-tiny-r0.qcow2 completed successfully
```
The disk is now ready:  
```bash
$ kubectl get -n uefi dv,pvc
NAME                                          PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-uefi-boot   Succeeded   N/A                   61s

NAME                                                               STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-uefi-boot                             Bound    pvc-98eb29f8-b534-4b79-aba8-12e8ea227247   1Gi        RWX            storage-class-iscsi   <unset>                 61s
persistentvolumeclaim/prime-b006aa0c-f4cb-4d81-8da7-00e266b6a565   Bound    pvc-98eb29f8-b534-4b79-aba8-12e8ea227247   1Gi        RWX            storage-class-iscsi   <unset>                 61s
```
For our test, I would like to connect to the VM using SSH.  
I then first need to create a key pair, and configure the cloud-init to include that key:  
```bash
$ ssh-keygen -t rsa -N "" -f /root/.ssh/alpine
$ kubectl create secret generic alpinepub -n uefi --from-file=key1=/root/.ssh/alpine.pub

$ kubectl create secret generic alpine-uefi-cloudinit-userdata -n uefi --from-literal=userdata="#cloud-config
users:
  - name: alpine
    ssh_authorized_keys:
      - $(kubectl get secret alpinepub -n uefi -o jsonpath='{.data.key1}' | base64 -d)
chpasswd:
  expire: false
ssh_pwauth: True
runcmd:
  - echo "alpine:alpine" | chpasswd
  - echo '######################################################' > /etc/motd
  - echo 'Welcome to UEFI Alpine on KubeVirt in the NetApp LoD!' >> /etc/motd
  - echo '######################################################' >> /etc/motd
  - apk add --no-cache lsblk parted tmux
"
```
Note that this init process also includes the installation of a few extra tools, such as _tmux_ that we will use to prove that LiveMigration is functional.  

We can now apply the VM manifest (*alpine_uefi_vm.yaml*) for our UEFI based Alpine VM.  
Note that it requires a bit more memory than the BIOS one to work in this lab:  
```bash
$ kubectl create -f alpine_uefi_vm.yaml
virtualmachine.kubevirt.io/alpine-uefi-vm created
service/alpine-uefi-vm-ssh-lb created
```
Connecting to the VM can be achieved in multiple ways:  
- virtctl tool to use the VM console or ssh.  
- SSH against the VM IP address, or in our example a specific LoadBalancer service created to be used specifically for SSH

Using the LoadBalancer service avoids you to switch IP address each time the VM changes worker node. You can then always use the same address to connect to it.

OK, our VM is now ready:  
```bash
$ kubectl get -n uefi all,pvc
NAME                                     READY   STATUS    RESTARTS   AGE
pod/virt-launcher-alpine-uefi-vm-l48qq   2/2     Running   0          45s

NAME                            TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/alpine-uefi-vm-ssh-lb   LoadBalancer   10.96.198.112   192.168.0.213   22:31009/TCP   45s

NAME                                          PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-uefi-boot   Succeeded   N/A                   2m6s

NAME                                                AGE   PHASE     IP               NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-uefi-vm   45s   Running   192.168.25.126   rhel3      True

NAME                                        AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-uefi-vm   45s   Running   True

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-uefi-boot   Bound    pvc-98eb29f8-b534-4b79-aba8-12e8ea227247   1Gi        RWX            storage-class-iscsi   <unset>                 2m6s
```
Let's connect to the VM for the first time with SSH (you will create an alias to simplify command line):  
```bash
ALPINE_IP=$(kubectl get svc -n uefi alpine-uefi-vm-ssh-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && echo "$ALPINE_IP"
alias sshalp='ssh alpine@$ALPINE_IP -i /root/.ssh/alpine -o ServerAliveInterval=10 -o ServerAliveCountMax=3'
sshalp
```
You are now in the VM!  
You can easily see that it is running an UEFI mode, as the bootable file is located on a specific partition (/boot/efi):  
```bash
######################################################
Welcome to UEFI Alpine on KubeVirt in the NetApp LoD!
######################################################
alpine-uefi-vm:~$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda    253:0    0    1G  0 disk
├─vda1 253:1    0  512K  0 part /boot/efi
└─vda2 253:2    0 1023M  0 part /
vdb    253:16   0    1M  0 disk

alpine-uefi-vm:~$ doas ls /boot/efi/EFI/boot
bootx64.efi
```
Just to compare with a BIOS based Virtual Machine, you would get the following with such mode:  
```bash
#################################################
Welcome to Alpine on KubeVirt in the NetApp LoD!
#################################################
alpine-vm:~$ lsblk
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda  253:0    0   1G  0 disk /
vdb  253:32   0   1M  0 disk
```
Note: _vdb_ corresponds to the small _cloud-init_ disk.  

From a KubeVirt perspective, is that VM compatible with LiveMigration:  
```bash
$ kubectl get vmi -n uefi alpine-uefi-vm -o jsonpath='NAME={.metadata.name}{"\t"}PHASE={.status.phase}{"\t"}LIVE={range .status.conditions[?(@.type=="LiveMigratable")]}{.status}{end}{"\t"}NODE={.status.nodeName}{"\n"}'
NAME=alpine-uefi-vm  PHASE=Running   LIVE=True       NODE=rhel3
```
Let's see that in action!  
SSH is a TCP based tool, you will then be disconnected during the migration.  
However, in order to show that the VM itself has not stopped or crashed while changing nodes, we will start a TMUX session that displays the uptime. TMUX allows you to switch between sessions, or reattach to an existing one if needed.  

First, open a new terminal to run SSH:  
```bash
alpine-vm:~$ tmux new -s migtest
alpine-vm:~$ while true; do date; hostname; uptime; sleep 2; done
Sat Aug  1 13:47:27 UTC 2026
alpine-uefi-vm.uefi.svc.cluster.local
 13:47:27 up 20 min,  0 users,  load average: 0.01, 0.02, 0.00
Sat Aug  1 13:47:29 UTC 2026
alpine-uefi-vm.uefi.svc.cluster.local
 13:47:29 up 20 min,  0 users,  load average: 0.01, 0.02, 0.00
```
In a second terminal, monitor the change of IP address of the Virtual Machine Instance:  
```bash
$ kubectl -n uefi get endpointslice -l kubernetes.io/service-name=alpine-uefi-vm-ssh-lb -w
NAME                          ADDRESSTYPE   PORTS   ENDPOINTS        AGE
alpine-uefi-vm-ssh-lb-ttqrq   IPv4          22      192.168.25.126   19m
alpine-uefi-vm-ssh-lb-ttqrq   IPv4          22      192.168.25.126,192.168.28.96   22m
alpine-uefi-vm-ssh-lb-ttqrq   IPv4          22      192.168.25.126,192.168.28.96   23m
alpine-uefi-vm-ssh-lb-ttqrq   IPv4          22      192.168.25.126,192.168.28.96   23m
alpine-uefi-vm-ssh-lb-ttqrq   IPv4          22      192.168.28.96                  23m
```
An **EndpointSlice** is the Kubernetes resource that tracks the real network endpoints behind a Service.  
In our case, it is the object that tells Kubernetes which VM IP currently receives traffic. During live migration, you can see the EndpointSlice change from the old VM IP to the new one.  

In a third terminal, launch the VM migration, which happens very quickly :  
```bash
$ virtctl migrate -n uefi alpine-uefi-vm
VM alpine-uefi-vm was scheduled to migrate

$ kubectl get -n uefi all,pvc
NAME                                     READY   STATUS      RESTARTS   AGE
pod/virt-launcher-alpine-uefi-vm-jpf22   2/2     Running     0          19s
pod/virt-launcher-alpine-uefi-vm-l48qq   0/2     Completed   0          23m

NAME                            TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/alpine-uefi-vm-ssh-lb   LoadBalancer   10.96.198.112   192.168.0.213   22:31009/TCP   23m

NAME                                          PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-uefi-boot   Succeeded   N/A                   24m

NAME                                                                    PHASE       VMI
virtualmachineinstancemigration.kubevirt.io/kubevirt-migrate-vm-nlb9c   Succeeded   alpine-uefi-vm

NAME                                                AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-uefi-vm   23m   Running   192.168.28.96   rhel2      True

NAME                                        AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-uefi-vm   23m   Running   True

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-uefi-boot   Bound    pvc-98eb29f8-b534-4b79-aba8-12e8ea227247   1Gi        RWX            storage-class-iscsi   <unset>                 24m
```
A few things to note:  
- a VirtualMachineInstanceMigration resource was created.  
- the IP address of the VMI changed, which you can also see in the EndPointSlice block above.  
- the LoadBalancer service did not change.  

You can also see that the SSH session may break during endpoint handoff.
However, the tmux session inside the VM survives.
Your loop/process is still running after reattach.:  
```bash
sshalp
######################################################
Welcome to UEFI Alpine on KubeVirt in the NetApp LoD!
######################################################
alpine-uefi-vm:~$ tmux attach -t  migtest
Sat Aug  1 13:53:08 UTC 2026
alpine-uefi-vm.uefi.svc.cluster.local
 13:53:08 up 26 min,  0 users,  load average: 0.07, 0.02, 0.00
Sat Aug  1 13:53:10 UTC 2026
alpine-uefi-vm.uefi.svc.cluster.local
 13:53:10 up 26 min,  0 users,  load average: 0.07, 0.02, 0.00
```
As you can see, the uptime did not restart from scratch!  
LiveMigration test successful!  

Let's dig into the VirtualMachineInstanceMigration (_VMIM_).  
A **VirtualMachineInstanceMigration** is the KubeVirt object that tracks and manages the live migration of a running VirtualMachineInstance between Kubernetes nodes.  
What do its events tell us:  
```bash
$ kubectl get events -n uefi --field-selector involvedObject.kind=VirtualMachineInstanceMigration
LAST SEEN   TYPE     REASON                OBJECT                                                      MESSAGE
14m         Normal   SuccessfulCreate      virtualmachineinstancemigration/kubevirt-migrate-vm-nlb9c   Created migration target pod virt-launcher-alpine-uefi-vm-jpf22
14m         Normal   SuccessfulHandOver    virtualmachineinstancemigration/kubevirt-migrate-vm-nlb9c   Migration target pod is ready for preparation by virt-handler.
14m         Normal   SuccessfulMigration   virtualmachineinstancemigration/kubevirt-migrate-vm-nlb9c   Source node reported migration succeeded
```
Everything looks good.  
What migration configuration is reported for this run?  
```bash
$ kubectl get -n uefi vmim -o yaml
  status:
    migrationState:
      completed: true
      endTimestamp: "2026-08-01T13:49:20Z"
      migrationConfiguration:
        allowAutoConverge: false
        allowPostCopy: false
        allowWorkloadDisruption: false
        bandwidthPerMigration: "0"
        completionTimeoutPerGiB: 150
        nodeDrainTaintKey: kubevirt.io/drain
        parallelMigrationsPerCluster: 5
        parallelOutboundMigrationsPerNode: 2
        progressTimeout: 150
        unsafeMigrationOverride: false
```
These parameters define the cluster-wide behavior of KubeVirt live migrations, including speed limits, timeouts, parallelism, and whether more aggressive migration techniques are allowed. 

They are configured in the KubeVirt custom resource under _spec.configuration.migrations_.  
Here are some explanations:  
- `allowAutoConverge`: Allows KubeVirt to slow down the VM vCPUs if memory changes too quickly during migration, helping the migration finish.  
- `allowPostCopy`: Allows the VM to start running on the target node before all memory has been copied, which can help difficult migrations complete faster.  
- `allowWorkloadDisruption`: Allows KubeVirt to use more disruptive migration methods when needed to make sure the migration completes.  
- `bandwidthPerMigration`: Sets the maximum network bandwidth that one migration is allowed to consume.  
- `completionTimeoutPerGiB`: Sets how long a migration is allowed to run per GiB of VM memory before timing out.  
- `nodeDrainTaintKey`: Defines the taint key used when a node is being drained, so KubeVirt knows when VMs should be moved away.  
- `parallelMigrationsPerCluster`: Sets the maximum number of VM live migrations that can run at the same time in the whole cluster.  
- `parallelOutboundMigrationsPerNode`: Sets the maximum number of VM migrations that can leave one source node at the same time.  
- `progressTimeout`: Sets how long KubeVirt waits without seeing migration progress before considering the migration stalled.  
- `unsafeMigrationOverride`: Allows KubeVirt to bypass some migration safety checks; this is risky and should normally stay disabled.  

## B. UEFI Secure Boot Virtual Machine

Alpine Linux installation media do not natively support UEFI Secure Boot out of the box.  
You could however create a virtual machine with Alpine, and then enable Secure Boot.  

As the goal of this chapter is to showcase the support for LivreMigration, let's use an image that already supports SecureBoot natively, such as Ubuntu, which you can retrieve on the following link:    
```bash
mkdir -p ~/images
wget -P /root/images https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
```
Next step is to create the DataVolume, and to upload the Ubuntu image to the corresponding PVC:  
```bash
$ kubectl create ns uefib
namespace/uefib created

$ kubectl create -f ubuntu_uefi_dv.yaml
datavolume.cdi.kubevirt.io/ubuntu-uefisb-boot created

$ virtctl image-upload dv ubuntu-uefisb-boot \
--namespace uefisb \
--image-path=/root/images/ubuntu-24.04-minimal-cloudimg-amd64.img \
--size=5Gi \
--insecure \
--uploadproxy-url=https://192.168.0.212:443
```
The disk is now ready:  
```bash
$ kubectl get -n uefisb all,pvc
NAME                                            PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/ubuntu-uefisb-boot   Succeeded   N/A                   70s

NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/ubuntu-uefisb-boot   Bound    pvc-b62594cb-f364-4e2f-a3b6-bbab29b17e71   5Gi        RWX            storage-class-iscsi   <unset>                 70s
```
In order to customize the VM so that it can be accessed via SSH, let's create a new key pair, as well as the secret for the cloud-init process:  
```bash
$ ssh-keygen -t rsa -N "" -f /root/.ssh/ubuntu
$ kubectl create secret generic ubuntupub -n uefisb --from-file=key1=/root/.ssh/ubuntu.pub

$ kubectl create secret generic ubuntu-uefisb-cloudinit-userdata -n uefisb --from-literal=userdata="#cloud-config
users:
  - name: ubuntu
    shell: /bin/bash
    sudo: \"ALL=(ALL) NOPASSWD:ALL\"
    ssh_authorized_keys:
      - $(kubectl get secret ubuntupub -n uefisb -o jsonpath='{.data.key1}' | base64 -d)
chpasswd:
  expire: false
  users:
    - name: ubuntu
      password: ubuntu
      type: text
ssh_pwauth: True
runcmd:
  - echo '######################################################' > /etc/motd
  - echo 'Welcome to UEFI Ubuntu on KubeVirt in the NetApp LoD!' >> /etc/motd
  - echo '######################################################' >> /etc/motd
"
```
Time to finally create the virtual machine, which is joined by a service specifically created for SSH connectivity:  
```bash
$ kubectl create -f ubuntu_uefi_vm.yaml
virtualmachine.kubevirt.io/ubuntu-uefisb-vm created
service/ubuntu-uefisb-vm-ssh-lb created

$ kubectl get -n uefisb all,pvc
NAME                                       READY   STATUS    RESTARTS   AGE
pod/virt-launcher-ubuntu-uefisb-vm-6v4r7   2/2     Running   0          34s

NAME                              TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/ubuntu-uefisb-vm-ssh-lb   LoadBalancer   10.96.137.140   192.168.0.213   22:31468/TCP   34s

NAME                                            PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/ubuntu-uefisb-boot   Succeeded   N/A                   4m21s

NAME                                                  AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/ubuntu-uefisb-vm   34s   Running   192.168.25.65   rhel3      True

NAME                                          AGE   STATUS    READY
virtualmachine.kubevirt.io/ubuntu-uefisb-vm   34s   Running   True

NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/ubuntu-uefisb-boot   Bound    pvc-b62594cb-f364-4e2f-a3b6-bbab29b17e71   5Gi        RWX            storage-class-iscsi   <unset>                 4m21s
```
Everything looks good!  
You can connect with the console to follow the boot sequence, or wait a couple of minutes to use SSH:  
```bash
virtctl console ubuntu-uefisb-vm -n uefisb
```
To connect via SSH, you would use the LoadBalancer service. Let's also create an alias to make it easier:    
```bash
$ UBUNTU_IP=$(kubectl get svc -n uefisb ubuntu-uefisb-vm-ssh-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && echo "$UBUNTU_IP"
$ alias sshubuntu='ssh ubuntu@$UBUNTU_IP -i /root/.ssh/ubuntu -o ServerAliveInterval=10 -o ServerAliveCountMax=3'
$ sshubuntu
######################################################
Welcome to UEFI Ubuntu on KubeVirt in the NetApp LoD!
######################################################
```
Now, how to make sure that SecureBoot is enabled, pretty straightforward:  
```bash
ubuntu@ubuntu-uefisb-vm:~$ sudo -i
root@ubuntu-uefisb-vm:~# dmesg | grep -i secure
[    0.000000] secureboot: Secure boot enabled
[    0.000000] Kernel is locked down from EFI Secure Boot mode; see man kernel_lockdown.7
[    0.059993] secureboot: Secure boot enabled
[    3.867910] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing: 61482aa2830d0ab2ad5af10b7250da9033ddcef0'
[    3.869905] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (2017): 242ade75ac4a15e50d50c84b0d45ff3eae707a03'
[    3.871693] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (ESM 2018): 365188c1d374d6b07c3c8f240f8ef722433d6a8b'
[    3.873681] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (2019): c0746fd6c5da3ae827864651ad66ae47fe24b3e8'
[    3.874570] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (2021 v1): a8d54bbb3825cfb94fa13c9f8a594a195c107b8d'
[    3.876476] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (2021 v2): 4cf046892d6fd3c9a5b03f98d845f90851dc6a8c'
[    3.878725] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (2021 v3): 100437bb6de6e469b581e61cd66bce3ef4ed53af'
[    3.880539] Loaded X.509 cert 'Canonical Ltd. Secure Boot Signing (Ubuntu Core 2019): c1d57b8f6b743f23ee41f4f7ee292f06eecadfb9'

root@ubuntu-uefisb-vm:~# mokutil --sb-state
SecureBoot enabled
```
Can't be any clearer!  
Let's verify that this virtual machine support LiveMigration from a KubeVirt perspective:  
```bash
$ kubectl get vmi -n uefisb ubuntu-uefisb-vm -o jsonpath='NAME={.metadata.name}{"\t"}PHASE={.status.phase}{"\t"}LIVE={range .status.conditions[?(@.type=="LiveMigratable")]}{.status}{end}{"\t"}NODE={.status.nodeName}{"\n"}'
NAME=ubuntu-uefisb-vm   PHASE=Running   LIVE=True       NODE=rhel3
```
Before moving this VM, let's check its uptime:  
```bash
$ sshubuntu uptime
 09:38:09 up 11 min,  1 user,  load average: 0.10, 0.54, 0.65
```
The goal is to make sure the uptime does not go back to 0 after the migration:  
```bash
$ virtctl migrate -n uefisb ubuntu-uefisb-vm
VM ubuntu-uefisb-vm was scheduled to migrate

$ kubectl get -n uefisb all,pvc
NAME                                       READY   STATUS      RESTARTS   AGE
pod/virt-launcher-ubuntu-uefisb-vm-6v4r7   0/2     Completed   0          13m
pod/virt-launcher-ubuntu-uefisb-vm-zxdh9   2/2     Running     0          23s

NAME                              TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
service/ubuntu-uefisb-vm-ssh-lb   LoadBalancer   10.96.137.140   192.168.0.213   22:31468/TCP   13m

NAME                                            PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/ubuntu-uefisb-boot   Succeeded   N/A                   17m

NAME                                                                    PHASE       VMI
virtualmachineinstancemigration.kubevirt.io/kubevirt-migrate-vm-dsddb   Succeeded   ubuntu-uefisb-vm

NAME                                                  AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/ubuntu-uefisb-vm   13m   Running   192.168.28.86   rhel2      True

NAME                                          AGE   STATUS    READY
virtualmachine.kubevirt.io/ubuntu-uefisb-vm   13m   Running   True

NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/ubuntu-uefisb-boot   Bound    pvc-b62594cb-f364-4e2f-a3b6-bbab29b17e71   5Gi        RWX            storage-class-iscsi   <unset>                 17m
```
That was also very quick, you can see tht the VMIM succeeded. Let's check the uptime of the Ubuntu VM again:  
```bash
$ sshubuntu uptime
 09:40:15 up 13 min,  1 user,  load average: 0.09, 0.37, 0.57
```
Tadaaa, another successful demonstration!  
We showed that UEFI based virtual machines with SecureBoot enabled support LiveMigration with RWX PVC configured as volumeMode=Block!  
