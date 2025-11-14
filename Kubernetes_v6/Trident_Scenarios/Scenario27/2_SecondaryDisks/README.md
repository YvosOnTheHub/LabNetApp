#########################################################################################
# SCENARIO 27: Managing multiple disks
#########################################################################################

In the previous chapter, you saw how to create a bootable disk from various source, as well as building a catalogue of those disks.  
We are going to cover here management tasks around secondary disks.  

## A. Chapter preparation

Let's create a new VM following the [Method3](../1_VMCreation/3_Method3/) explained earlier in this chapter.  
This will all happen in a new namespace called _disks_, where we begin with the creation of 2 disks (_boot_ & _data1_):  
```bash
$ kubectl create ns disks
namespace/disks created

$ kubectl create -f alpine_disks.yaml
datavolume.cdi.kubevirt.io/alpine-boot created
persistentvolumeclaim/alpine-data1 created
persistentvolumeclaim/alpine-data2 created
```
Note that I purposely used a DataVolume and two PVC to see if there a differences.  
One PVC will be declaratively defined in the VM specs, while the other one will be used later on in this chapter.  
You can now upload the Alpine image to the DataVolume:  
```bash
virtctl image-upload dv alpine-boot \
  --namespace disks \
  --image-path=/root/images/nocloud_alpine-3.22.1-x86_64-bios-tiny-r0.qcow2 \
  --size=1Gi \
  --insecure \
  --uploadproxy-url=https://192.168.0.212:443
```
You should now see the following:  
```bash
$ kubectl get -n disks dv,pvc
NAME                                     PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot   Succeeded   N/A                   2m3s

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot    Bound    pvc-5c1e6fb1-beb2-439d-8fbb-4d9b663253f0   1Gi        RWX            storage-class-iscsi   <unset>                 2m3s
persistentvolumeclaim/alpine-data1   Bound    pvc-c4f164b7-767f-411a-90de-c87c7d8650af   1Gi        RWX            storage-class-iscsi   <unset>                 2m3s
persistentvolumeclaim/alpine-data2   Bound    pvc-25d40ad2-1ac5-47af-9fcd-f4d9bcbbecd5   1Gi        RWX            storage-class-iscsi   <unset>                 2m3s
```
The VM manifest contains a CloudInit disk that performs 3 tasks:  
- set the password for the _alpine_ user  
- change the "message of the day"
- install extra packages that will help during volume resize.  
  
Go ahead and proceed with the VM creation:  
```bash
$ kubectl create -f alpine_vm.yaml
virtualmachine.kubevirt.io/alpine-vm created
```
After a few seconds, you will see the following:  
```bash
$ kubectl get -n disks all,pvc
Warning: kubevirt.io/v1 VirtualMachineInstancePresets is now deprecated and will be removed in v2.
NAME                                READY   STATUS    RESTARTS   AGE
pod/virt-launcher-alpine-vm-g7b9p   2/2     Running   0          42s

NAME                                     PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot   Succeeded   N/A                   6m52s

NAME                                           AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-vm   42s   Running   192.168.26.21   rhel1      True

NAME                                   AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-vm   42s   Running   True

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot    Bound    pvc-5c1e6fb1-beb2-439d-8fbb-4d9b663253f0   1Gi        RWX            storage-class-iscsi   <unset>                 6m52s
persistentvolumeclaim/alpine-data1   Bound    pvc-c4f164b7-767f-411a-90de-c87c7d8650af   1Gi        RWX            storage-class-iscsi   <unset>                 6m52s
persistentvolumeclaim/alpine-data2   Bound    pvc-0ee1cdcf-39b3-4f2b-8806-03d13246414c   1Gi        RWX            storage-class-iscsi   <unset>                 6m52s
```

## B. Disks analysis

Let's first connect to the VM to see what disks are displayed.  
```bash
$ virtctl console -n disks alpine-vm
Successfully connected to alpine-vm console. Press Ctrl+] or Ctrl+5 to exit console.
...
Welcome to Alpine Linux on KubeVirt in the NetApp LoD!

alpine-vm:~$ doas df -h
Filesystem                Size      Used Available Use% Mounted on
devtmpfs                 10.0M         0     10.0M   0% /dev
shm                      45.9M         0     45.9M   0% /dev/shm
/dev/vda                956.0M     90.5M    821.1M  10% /
tmpfs                    18.4M    120.0K     18.3M   1% /run

alpine-vm:~$ doas lsblk
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda  253:0    0   1G  0 disk /
vdb  253:16   0   1G  0 disk
vdc  253:32   0   1M  0 disk

alpine-vm:~$ doas fdisk -l /dev/vdb
Disk /dev/vdb: 1024 MB, 1073741824 bytes, 2097152 sectors
2080 cylinders, 16 heads, 63 sectors/track
Units: sectors of 1 * 512 = 512 bytes

Disk /dev/vdb doesn't contain a valid partition table
```
What do we see:  
- **/dev/vda** corresponds to the **boot** disk  
- **/dev/vdb** corredponds to the **data1** PVC, and is currently empty  
- **/dev/vdc** represents the **CloudInit** volume  

Let's prepare the data1 disks (partition, format, mount) and create a file in the folder.  
Note that Alpine does not use _sudo_, but rather _doas_:  
```bash
# partition, format, mount
echo -e "o\nn\np\n1\n\n\nw" | doas fdisk /dev/vdb
doas mkfs.ext4 /dev/vdb1
doas mkdir /data1
doas mount /dev/vdb1 /data1
doas chmod 777 /data1
UUID=$(doas blkid -s UUID -o value /dev/vdb1) && echo "UUID=$UUID   /data1   ext4   defaults   0 0" | doas tee -a /etc/fstab

# create file
echo "This is my test for Scenario27." > /data1/file.txt
```
You can now see a new disk available:  
```bash
alpine-vm:~$ doas df -h
Filesystem                Size      Used Available Use% Mounted on
devtmpfs                 10.0M         0     10.0M   0% /dev
shm                      45.9M         0     45.9M   0% /dev/shm
/dev/vda                956.0M     90.5M    821.1M  10% /
tmpfs                    18.4M    120.0K     18.3M   1% /run
/dev/vdb1               989.4M    276.0K    921.9M   0% /data1

alpine-vm:~$ doas lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda    253:0    0    1G  0 disk /
vdb    253:16   0    1G  0 disk
└─vdb1 253:17   0 1023M  0 part /data1
vdc    253:32   0    1M  0 disk
```

## C. Cloud init disk removal

As this disk is not **HotPluggable**, you need to manually edit the VM definition and restart it:  
```bash
$ kubectl -n disks patch vm alpine-vm --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/domain/devices/disks/2"},
  {"op": "remove", "path": "/spec/template/spec/volumes/2"}
]'
virtualmachine.kubevirt.io/alpine-vm patched

$ virtctl restart alpine-vm -n disks
VM alpine-vm was scheduled to restart
```
Give it a couple of minutes to boot, at which point to can log in again and check the CloudInit disk was actually removed:  
```bash
alpine-vm:~$ doas fdisk -l /dev/vdc
fdisk: can't open '/dev/vdc': No such file or directory

alpine-vm:~$ doas lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda    253:0    0    1G  0 disk /
vdb    253:16   0    1G  0 disk
└─vdb1 253:17   0 1023M  0 part /data1
```

## D. PVC Resize

We will see here how to resize the _alpine-data1_ PVC, as well as the operations that must be performed within the Virtual Machine.  
Let's perform this with a simple patch. It takes a few seconds for the operation to complete:  
```bash
$ kubectl patch -n disks pvc alpine-data1 -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
persistentvolumeclaim/alpine-data1 patched

$ kubectl get -n disks pvc alpine-data1
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
alpine-data1   Bound    pvc-c4f164b7-767f-411a-90de-c87c7d8650af   2Gi        RWX            storage-class-iscsi   <unset>                 57m
```
The PVC is resized, but what is the situation within the VM:  
```bash
alpine-vm:~$ doas df -h /data1
Filesystem                Size      Used Available Use% Mounted on
/dev/vdb1               989.4M    276.0K    921.9M   0% /data1

alpine-vm:~$ doas lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda    253:0    0    1G  0 disk /
vdb    253:16   0    2G  0 disk
└─vdb1 253:17   0 1023M  0 part /data1
```
Good news, the VM sees a 2Gi disk, but the partition has not yet been resized. Let's try that too:  
```bash
# resize the partition 1 so its end moves to the end of the disk
alpine-vm:~$ doas parted /dev/vdb resizepart 1 100%
# ask the kernel to re-read the partition table
alpine-vm:~$ doas partprobe /dev/vdb

# at this point, the partition now has the correct size
alpine-vm:~$ doas lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda    253:0    0   1G  0 disk /
vdb    253:16   0   2G  0 disk
└─vdb1 253:17   0   2G  0 part /data1

# just need to resize the filesystem now
alpine-vm:~$ doas umount /data1
alpine-vm:~$ doas e2fsck -f /dev/vdb1
alpine-vm:~$ doas resize2fs /dev/vdb1
alpine-vm:~$ doas mount /dev/vdb1 /data1

# result
alpine-vm:~$ doas df -h /data1
Filesystem                Size      Used Available Use% Mounted on
/dev/vdb1                 1.9G    280.0K      1.8G   0% /data1
```
There you go, disk, partition & filesystem resized!

## E. Dynamically manage a third disk

This possible thanks to multiple feature gates configured in KubeVirt:  
- **HotplugVolumes** (imperative mode): enables attach/detach of volumes to a running VMI (with virtctl for instance)
- **DeclarativeHotplugVolumes** (declarative mode): lets you modify the VM specifications

Let's use the first method to mount the PVC _alpine-data2_:  
```bash
$ virtctl addvolume alpine-vm -n disks --volume-name=alpine-data2 --persist
Successfully submitted add volume request to VM alpine-vm for volume alpine-data2
```
What does that trigger?  
First, a new pod is made available:  
```bash
$ kubectl get -n disks po -l kubevirt.io=hotplug-disk
NAME                  READY   STATUS    RESTARTS   AGE
pod/hp-volume-bxx4f   1/1     Running   0          2m28s

$ kubectl describe -n disks pod/hp-volume-bxx4f
...
Containers:
  hotplug-disk:
    Devices:
      /path/alpine-data2/25d40ad2-1ac5-47af-9fcd-f4d9bcbbecd5 from alpine-data2
...
Volumes:
  alpine-data2:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  alpine-data2
    ReadOnly:   false
...
```
This pod is automatically launched by the virt-controller when the hotplug request was created.  
It first mounts the PVC and the block device on the node where the VMI is running on, then signals the virt-launcher to attach the device to the running VMI. Removing the volume automatically deletes the pod.  

As we added the **--persist** flag to the virtctl command, you should also find an update to the VM definition:  
```bash
$ kubectl describe -n disks virtualmachine.kubevirt.io/alpine-vm
...
      Volumes:
        Name:          alpine-data2
        Persistent Volume Claim:
          Claim Name:    alpine-data2
          Hotpluggable:  true
...
```
The most interesting information can be found in the VMI:  
```bash
$ kdesc -n disks virtualmachineinstance.kubevirt.io/alpine-vm
...
  Volume Status:
    Hotplug Volume:
      Attach Pod Name:  hp-volume-bxx4f
      Attach Pod UID:   245be665-b6c2-488a-b4a4-de73d5fa92a0
    Message:            Successfully attach hotplugged volume alpine-data2 to VM
    Name:               alpine-data2
    Persistent Volume Claim Info:
      Access Modes:
        ReadWriteMany
      Capacity:
        Storage:            1Gi
      Claim Name:           alpine-data2
      Filesystem Overhead:  0
      Requests:
        Storage:    1Gi
      Volume Mode:  Block
    Phase:          Ready
    Reason:         VolumeReady
    Target:         sda
...
Events:
  Type    Reason              Age   From                       Message
  ----    ------              ----  ----                       -------
  Normal  SuccessfulCreate    21m   virtualmachine-controller  Created attachment pod hp-volume-bxx4f
  Normal  SuccessfulCreate    21m   virtualmachine-controller  Created hotplug attachment pod hp-volume-bxx4f, for volume alpine-data2
  Normal  VolumeMountedToPod  21m   virt-handler               Volume alpine-data2 has been mounted in virt-launcher pod
  Normal  VolumeReady         21m   virt-handler               Successfully attach hotplugged volume alpine-data2 to VM
```
Now, let's connect to the VM to see the result:  
```bash
alpine-vm:~$ doas lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   1G  0 disk
vda    253:0    0   1G  0 disk /
vdb    253:16   0   2G  0 disk
└─vdb1 253:17   0   2G  0 part /data1

alpine-vm:~$ doas fdisk -l /dev/sda
Disk /dev/sda: 1 GiB, 1073741824 bytes, 2097152 sectors
Disk model: QEMU HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```
The disk is correctly attached, but nothing else was performed. 
Like we did for the first data disk, let's configure this new disk (partition, format, mount):  
```bash
# partition, format, mount
echo -e "o\nn\np\n1\n\n\nw" | doas fdisk /dev/sda
doas mkfs.ext4 /dev/sda1
doas mkdir /data2
doas mount /dev/sda1 /data2
doas chmod 777 /data2
UUID=$(doas blkid -s UUID -o value /dev/sda1) && echo "UUID=$UUID   /data2   ext4   defaults   0 0" | doas tee -a /etc/fstab
```
The disk is now usable under the folder /data2:  
```bash
alpine-vm:~$ doas df -h /data2
Filesystem                Size      Used Available Use% Mounted on
/dev/sda1               988.4M    276.0K    921.0M   0% /data2

alpine-vm:~$ echo "This is my third disk." > /data2/file.txt
```
Notice that the 2 first disks are named _vdX_, while the new disk is names _sdX_.  
- /dev/vdX volumes are **static volumes** attached as virtio-blk devices and present in the initial definition of the VM.  
- /dev/sdX volumes are **hot plugged**, and use a SCSI controller.  

Let's leave the Virtual Machine and resize the volume, operation that takes a few 10s of seconds to complete:  
```bash
$ kubectl -n disks patch pvc alpine-data2 -p '{"spec":{"resources":{"requests":{"storage":"3Gi"}}}}'
persistentvolumeclaim/alpine-data2 patched

$ kubectl get -n disks pvc alpine-data2
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
alpine-data2   Bound    pvc-0ee1cdcf-39b3-4f2b-8806-03d13246414c   3Gi        RWX            storage-class-iscsi   <unset>                 131m
```
Let's reconnect to the VM to resize the partition and the filesystem:  
```bash
alpine-vm:~$ doas fdisk -l /dev/sda
Disk /dev/sda: 3 GiB, 3221225472 bytes, 6291456 sectors
Disk model: QEMU HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x6de8d3ec

Device     Boot Start     End Sectors  Size Id Type
/dev/sda1        2048 2097151 2095104 1023M 83 Linux

alpine-vm:~$ doas lsblk /dev/sda
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0    3G  0 disk
└─sda1   8:1    0 1023M  0 part /data2

# resize the partition 1 so its end moves to the end of the disk
alpine-vm:~$ doas parted /dev/sda resizepart 1 100%
# ask the kernel to re-read the partition table
alpine-vm:~$ doas partprobe /dev/sda
# at this point, the partition now has the correct size
alpine-vm:~$ doas lsblk /dev/sda
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   3G  0 disk
└─sda1   8:1    0   3G  0 part /data2

# just need to resize the filesystem now
alpine-vm:~$ doas umount /data2
alpine-vm:~$ doas e2fsck -f /dev/sda1
alpine-vm:~$ doas resize2fs /dev/sda1
alpine-vm:~$ doas mount /dev/sda1 /data2

# result
alpine-vm:~$ doas df -h /data2
Filesystem                Size      Used Available Use% Mounted on
/dev/sda1                 2.9G    280.0K      2.8G   0% /data2

# the file is still there
alpine-vm:~$ cat /data2/file.txt
This is my third disk.
```

We can also now try to remove the _alpine-data2_ volume.  
However, you first need to unmount the volume in the VM and update the _fstab_ file so that VM does not try to remount it at boot:
```bash
alpine-vm:~$ doas umount /data2
alpine-vm:~$ doas sed -i '/\/data2/d' /etc/fstab
```
You can now proceed with the removal of the disk:  
```bash
$ virtctl removevolume alpine-vm -n disks --volume-name=alpine-data2 --persist
Successfully submitted remove volume request to VM alpine-vm for volume alpine-data2
```
Applying this command will also delete the hotplug pod, as well as updated the VMI with the volume configuration.  
If you reconnect to the VM, you will see that the disk is now gone:  
```bash
alpine-vm:~$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda    253:0    0   1G  0 disk /
vdb    253:16   0   2G  0 disk
└─vdb1 253:17   0   2G  0 part /data1
```
Remember you created a file in a partition of that disk.  
What happens if you reconnect it to this VM?  
Let's first reuse the _addvolume_ option of virtctl:  
```bash
$ virtctl addvolume alpine-vm -n disks --volume-name=alpine-data2 --persist
Successfully submitted add volume request to VM alpine-vm for volume alpine-data2
```
And reconnect to the VM to mount the partition and check the content:  
```bash
alpine-vm:~$ lsblk /dev/sda
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   3G  0 disk
└─sda1   8:1    0   3G  0 part

alpine-vm:~$ doas mount /dev/sda1 /data2

alpine-vm:~$ doas df -h /data2
Filesystem                Size      Used Available Use% Mounted on
/dev/sda1                 2.9G    280.0K      2.8G   0% /data2

alpine-vm:~$ ls /data2
file.txt    lost+found
```