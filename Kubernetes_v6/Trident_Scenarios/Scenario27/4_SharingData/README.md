#########################################################################################
# SCENARIO 27: Sharing data between Virtual Machines
#########################################################################################

The previous chapters focused on creating VMs and attaching **disks** to a single guest.  
This chapter looks at a different problem: how can **two (or more) Virtual Machines** see the same files at the same time?

With KubeVirt there is no VMware-style datastore where every VM simply opens the same folder.  
Each disk is a PVC, and concurrent access is a storage-and-protocol problem, not a hypervisor default.

There are several workable patterns. None of them is universally "best"; they trade simplicity, semantics (files vs raw blocks), live migration, and data-integrity guarantees.

**TL;DR START**  
Use **VirtioFS + an RWX Filesystem PVC** (NFS via Trident) when guests should share a POSIX directory.  
Use **in-guest NFS/SMB to ONTAP** when you want native NAS semantics, real NFS locking, and UID handling without the virtiofsd caveats.  
Use a **shareable RWX block disk** only with a clustered filesystem or an application that coordinates I/O; a regular ext4 on that disk **will corrupt**.  
Use **VirtioFS + ConfigMap/Secret** only for small configuration, not application data.  
**TL;DR STOP**

Comparison at a glance:

| Method | What the guest sees | Typical backend in this lab | Concurrent RW | Live migration | Main risk / limit |
| --- | --- | --- | --- | --- | --- |
| VirtioFS + ConfigMap/Secret | A directory of files | Kubernetes object | Yes (tiny data) | Yes (KubeVirt >= v1.5) | Size, not a data plane |
| VirtioFS + PVC | A directory of files | `storage-class-nfs` RWX Filesystem | Yes | Yes, if the PVC is RWX | virtiofsd UID **107**, xattr, no volume migration |
| In-guest NFS (or SMB) | A NAS mount | Same ONTAP export as the PVC, or a dedicated SVM path | Yes | Friendly (network FS) | Guest needs NFS client + route to SVM |
| Shareable RWX block disk | A raw `/dev/vdX` | `storage-class-iscsi` RWX Block | Yes at block layer | Friendly with RWX | **Corruption** without clustered FS |
| Sequential hotplug | A disk owned by one VM at a time | Any PVC | No | N/A while detached | Not concurrent sharing |

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>

**ATTENTION:**  
Attaching the same block PVC to two VMs as a normal disk without `shareable: true` is rejected or locked by QEMU.  
Setting `shareable: true` only removes the lock. It does **not** make ext4/xfs cluster-aware.  
If you need a shared **folder**, prefer VirtioFS or in-guest NFS. If you need a shared **LUN**, you need GFS2/OCFS2 (or similar) inside the guests.

<p align="center">:boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom: :boom:</p>

## A. Chapter preparation

This chapter lives in the namespace _share_.  
You also need two KubeVirt feature gates (already present on recent KubeVirt for ConfigMaps, still required for PVC-backed VirtioFS):

- **EnableVirtioFsConfigVolumes**: share ConfigMaps, Secrets, ServiceAccounts, DownwardAPI through VirtioFS. Graduated to GA in KubeVirt 1.8 (so lab clusters on 1.9 already allow it; 1.6.6 / 1.7.4 still need the gate).  
- **EnableVirtioFsStorageVolumes**: share PVCs / DataVolumes through VirtioFS. Still gated.

Patch the existing list (a merge of `featureGates` **replaces** the array, so keep the gates from [Addenda15](../../../Addendum/Addenda15/)):  
```bash
$ kubectl -n kubevirt patch kubevirt kubevirt --type=merge \
  -p '{"spec":{"configuration":{"developerConfiguration":{"featureGates":["ExpandDisks","HotplugVolumes","DeclarativeHotplugVolumes","Snapshot","EnableVirtioFsConfigVolumes","EnableVirtioFsStorageVolumes"]}}}}'
kubevirt.kubevirt.io/kubevirt patched
```

Create the namespace and the shared objects (ConfigMap + NFS PVC):  
```bash
$ kubectl create ns share
namespace/share created

$ kubectl create -f shared_configmap.yaml
configmap/shared-config created

$ kubectl create -f shared_nfs_pvc.yaml
persistentvolumeclaim/shared-nfs created
```

Boot disks follow [Method3](../1_VMCreation/3_Method3/) (DataVolume + `virtctl image-upload`) for the first VM, then a DataVolume **clone** for the second so you do not upload twice:  
```bash
$ kubectl create -f alpine_boot.yaml
datavolume.cdi.kubevirt.io/alpine-boot-vm1 created

$ CDILBIP=$(kubectl -n cdi get svc cdi-uploadproxy-lb -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

$ virtctl image-upload dv alpine-boot-vm1 \
  --namespace share \
  --image-path=/root/images/nocloud_alpine-3.22.1-x86_64-bios-tiny-r0.qcow2 \
  --size=1Gi \
  --insecure \
  --uploadproxy-url=https://$CDILBIP
```

When the first DataVolume is `Succeeded`, clone it:  
```bash
$ kubectl create -f alpine_boot_clone.yaml
datavolume.cdi.kubevirt.io/alpine-boot-vm2 created
```

You should end up with two boot PVCs plus the NFS share:  
```bash
$ kubectl get -n share dv,pvc
NAME                                         PHASE       PROGRESS   RESTARTS   AGE
datavolume.cdi.kubevirt.io/alpine-boot-vm1   Succeeded   N/A                   3m
datavolume.cdi.kubevirt.io/alpine-boot-vm2   Succeeded   N/A                   45s

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/alpine-boot-vm1    Bound    pvc-f7017ade-d55f-49ae-bb3f-872c4259ed64   1Gi        RWX            storage-class-iscsi   <unset>                 3m
persistentvolumeclaim/alpine-boot-vm2    Bound    pvc-a64d4542-349c-4ab0-8d85-cbcc153f5a37   1Gi        RWX            storage-class-iscsi   <unset>                 45s
persistentvolumeclaim/shared-nfs         Bound    pvc-dfe8adb5-c1ed-4c60-9532-9addb75bbda6   1Gi        RWX            storage-class-nfs     <unset>                 3m
```

Note: VirtioFS needs a guest kernel that provides the `virtiofs` filesystem (Linux 5.4+, or 4.18 on RHEL). The Alpine nocloud image used in this scenario does. If `mount -t virtiofs` fails, run `modprobe virtiofs` inside the guest.  
VirtioFS also adds a `virtiofsd` process next to QEMU, so these VMs request **512Mi** rather than the 128Mi used in earlier Alpine examples.

## B. Standard VirtioFS (ConfigMap / Secret)

"Standard" VirtioFS in KubeVirt is not a hostPath bind-mount of a random node directory.  
KubeVirt presents a Kubernetes volume (ConfigMap, Secret, ServiceAccount, …) as a **filesystem** device. The guest mounts it with:  
```text
mount -t virtiofs <filesystem.name> <path>
```

The tag is `spec.domain.devices.filesystems[].name`, and it must match `spec.volumes[].name`.

**Pros**
- Changes to the ConfigMap/Secret show up in the guest **without a reboot** (unlike the ISO-disk method).  
- Perfect for injecting configuration, certificates, or a small “contract” between VMs.  
- No extra PVC.

**Cons**
- Hard size limits (ConfigMaps/Secrets are etcd objects, not a data volume).  
- Read-oriented; guests should not treat this as writable application storage.  
- Historically VirtioFS blocked live migration. That is no longer true: since KubeVirt v1.5 a VMI with `filesystems` devices is live-migratable (see section C).

Create both VMs. The manifests already attach the ConfigMap **and** the NFS PVC as VirtioFS filesystems (the PVC part is used in the next section):  
```bash
$ kubectl create -f alpine_vm1_virtiofs.yaml -f alpine_vm2_virtiofs.yaml
virtualmachine.kubevirt.io/alpine-vm1 created
virtualmachine.kubevirt.io/alpine-vm2 created
```

Wait until both are running, then open a console on each (`alpine` / `alpine`):  
```bash
$ kubectl get -n share vm,vmi
NAME                                    AGE   STATUS    READY
virtualmachine.kubevirt.io/alpine-vm1   73s   Running   True
virtualmachine.kubevirt.io/alpine-vm2   73s   Running   True

NAME                                            AGE   PHASE     IP              NODENAME   READY
virtualmachineinstance.kubevirt.io/alpine-vm1   73s   Running   192.168.28.94   rhel2      True
virtualmachineinstance.kubevirt.io/alpine-vm2   73s   Running   192.168.28.93   rhel2      True

$ virtctl console -n share alpine-vm1
$ virtctl console -n share alpine-vm2
```

Inside **each** guest you should already have `/mnt/config` (cloud-init mounts it). If not:  
```bash
modprobe virtiofs
mkdir -p /mnt/config
doas mount -t virtiofs config-fs /mnt/config
doas ls -l /mnt/config
```

You should see `welcome.txt` and `app.conf`.  
Now edit the ConfigMap from the control plane and watch the file change **inside both VMs** without restarting them:  
```bash
$ kubectl -n share patch configmap shared-config --type=merge -p '{"data":{"welcome.txt":"Updated from Kubernetes while both VMs are running.\n"}}'
configmap/shared-config patched
```

Back in a guest. The file does **not** change the instant the patch returns: kubelet only rewrites ConfigMap/Secret volumes on its periodic sync (`syncFrequency`, default **1m**), then virtiofsd serves whatever is already on disk in the virt-launcher pod. Wait up to about a minute (the two VMs can refresh a few seconds apart) and `cat` again:  
```bash
alpine-vm1:~$ cat /mnt/config/welcome.txt
Updated from Kubernetes while both VMs are running.
```

Same content on vm2. That is the ConfigMap VirtioFS model: Kubernetes is the source of truth, VMs are consumers.

## C. VirtioFS backend with a PVC (NFS RWX)

This is the pattern people usually mean by “share a folder between VMs” on KubeVirt.

KubeVirt mounts the PVC in the virt-launcher pod and runs **virtiofsd** (non-privileged) so the guest sees a directory tree.  
Because both virt-launcher pods must mount the volume at once, the PVC **must** be:

- `accessModes: [ReadWriteMany]`  
- `volumeMode: Filesystem`  
- a NAS storage class, here **storage-class-nfs** (Trident → ONTAP NFS)

A block iSCSI PVC cannot be “a folder” for VirtioFS.

**Pros**
- POSIX directory in the guest: no partition/format/fstab dance like a secondary disk.  
- Both VMs (and even a regular Pod) can use the **same** Trident PVC.  
- Capacity, snapshots, and protection stay on the Kubernetes/ONTAP object you already know.  
- Better fit for shared content, build artifacts, or a common data drop than ConfigMaps.

**Cons**
- virtiofsd runs as QEMU UID/GID **107** and cannot switch to another UID/GID, so **only `root` (UID 0) or UID 107 inside the guest can create files** on the share; any other user gets `Operation not permitted` even on a `0777` directory (see the note below). New files are always owned by 107:107, whatever the guest UID was.  
- Files that UID/GID 107 cannot read are invisible in the guest, so the ONTAP volume must be readable by 107. The Trident `ontap-nas` backend here uses `unixPermissions: '---rwxrwxrwx'` (0777), which is enough. A `VirtualMachine` spec has no `securityContext`/`fsGroup` to fix this from the VM side (that is a Pod field and the KubeVirt API rejects it), so permissions have to come from the backend or storage class.  
- Extended attributes are not supported on this non-privileged daemon.  
- Feature gate `EnableVirtioFsStorageVolumes` is required.  
- Live migration **works** here (see the note below), but **volume migration** does not: you cannot live-migrate the VM onto a *different* PVC while a `filesystem` device uses it, because virtiofsd migrates only its own metadata and never copies the directory content.  
- HostPath-backed “VirtioFS of a node directory” exists in the docs and is **discouraged** (node affinity, SELinux, security). Do not use it in this lab.

The two VMs from section B already mount `shared-fs` from PVC `shared-nfs`. On **vm1**:  
```bash
alpine-vm1:~$ mount | grep virtiofs
config-fs on /mnt/config type virtiofs
shared-fs on /mnt/shared type virtiofs

alpine-vm1:~$ doas sh -c 'echo "written by alpine-vm1" > /mnt/shared/from-vm1.txt'
alpine-vm1:~$ ls -l /mnt/shared
-rw-r--r--    1 107      107             22 Sep  9 13:40 from-vm1.txt
```

On **vm2**:  
```bash
alpine-vm2:~$ cat /mnt/shared/from-vm1.txt
written by alpine-vm1

alpine-vm2:~$ doas sh -c 'echo "written by alpine-vm2" > /mnt/shared/from-vm2.txt'
```

> **Why `doas` and not the plain `alpine` user?**  
> As the unprivileged `alpine` user the same command fails, and the directory permissions are not the reason:  
> ```bash
> alpine-vm1:~$ ls -ld /mnt/shared
> drwxrwxrwx    2 root     root          4096 Sep  9 11:57 /mnt/shared
> alpine-vm1:~$ echo "written by alpine-vm1" > /mnt/shared/from-vm1.txt
> -sh: can't create /mnt/shared/from-vm1.txt: Operation not permitted
> ```
> The error is `EPERM`, not `EACCES`: the guest kernel allowed the write, virtiofsd refused it. When a file is created, the FUSE request carries the UID/GID of the guest process, and the non-privileged daemon accepts it only when that UID is **0** or its own **107** — anything else is rejected outright, because it has no `CAP_SETUID` to create the file under a foreign UID. Fixing the ONTAP `unixPermissions`, the mount options, or the PVC will not change this.  
>
> Two ways to write to the share:  
> - use `doas`/`root`, as above (files land as 107:107); or  
> - give the guest a UID 107 user and work as that user, which is handy if an application must run unprivileged:  
> ```bash
> alpine-vm1:~$ doas addgroup -g 107 qemu
> alpine-vm1:~$ doas adduser -D -u 107 -G qemu qemu
> alpine-vm1:~$ doas -u qemu sh -c 'echo "written as uid 107" > /mnt/shared/from-uid107.txt'
> ```
> Existing files are a different story: reading and appending to them only needs the usual POSIX bits, so a `0666`/`0777` file created by root can be updated by `alpine` without any of this.

Back on vm1 you should see both files.  
You can also prove the volume is a normal Kubernetes PVC by reading it from a throwaway Pod. Use `--rm -i` **without** `-t`: `--rm` is only allowed on an attached container (`-i`), and `-t` would request a TTY this one-shot `sh -c` does not need.  
```bash
$ kubectl -n share run nfs-check --rm -i --restart=Never \
  --image=quay.io/yvosonthehub/busybox:1.35.0 \
  --overrides='{"spec":{"containers":[{"name":"nfs-check","image":"quay.io/yvosonthehub/busybox:1.35.0","command":["sh","-c","ls -l /data; cat /data/from-vm1.txt"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"shared-nfs"}}]}}'
total 0
-rw-r--r--    1 107      107             19 Sep  9 14:01 from-uid107.txt
-rw-r--r--    1 107      107             22 Sep  9 13:43 from-vm1.txt
-rw-r--r--    1 107      107             22 Sep  9 13:59 from-vm2.txt
written by alpine-vm1
pod "nfs-check" deleted from share namespace
```


That is the point of this check: **alpine-vm1**, **alpine-vm2**, and a normal Kubernetes Pod all see the same directory, because they all use PVC `shared-nfs` on the same ONTAP volume.

### VirtioFS and live migration

Older documentation (and older versions of this lab) claimed a VM using VirtioFS cannot be live migrated. Check it yourself:  
```bash
$ kubectl get -n share vmi -o wide
NAME         AGE     PHASE     IP              NODENAME   READY   LIVE-MIGRATABLE   PAUSED
alpine-vm1   6m10s   Running   192.168.28.95   rhel2      True    True
alpine-vm2   6m10s   Running   192.168.28.96   rhel2      True    True
```

`LIVE-MIGRATABLE True` is correct and not a display bug. **KubeVirt v1.5** added live migration for VMIs with `filesystems` devices (virtiofsd 1.13 in the infra containers), and `virt-handler` now explicitly skips virtiofs-shared volumes when it decides whether a VMI is migratable. Both of our shares qualify: the ConfigMap is a Kubernetes object available on every node, and `shared-nfs` is an **RWX** Trident PVC, so the destination node mounts the very same ONTAP volume.

Prove it with a real migration (the lab has several workers, and migration is always to *another* node):  
```bash
$ virtctl migrate -n share alpine-vm1
VM alpine-vm1 was scheduled to migrate

$ kubectl get -n share vmim
NAME                        PHASE       VMI
kubevirt-migrate-vm-kj7nr   Succeeded   alpine-vm1
```

Then re-check the mounts in the guest: `/mnt/config` and `/mnt/shared` are still there, and the files written earlier are unchanged.

What is **still** unsupported is *volume* migration (`updateVolumesStrategy: Migration`, i.e. moving the VM to a different PVC while it runs): virtiofsd transfers only its internal metadata and never copies the file content, so KubeVirt refuses that mode for `filesystem` volumes. Plain live migration between nodes, which is what matters in this lab, is fine.


## D. In-guest NFS to ONTAP (bypass VirtioFS)

VirtioFS is a hypervisor/K8s path: PVC → virt-launcher mount → virtiofsd → guest.  
The other NAS path is classic: the **guest OS** mounts NFS (or SMB) straight to the SVM.

The PVC `shared-nfs` is already an ONTAP export. In this lab the NFS server and path are **not** on the PV (`spec.nfs` is empty). Read them from the TridentVolume (`tvol`) that matches the PVC’s volume name:  
```bash
$ kubectl get tvol -n trident $(kubectl -n share get pvc shared-nfs -o jsonpath='{.spec.volumeName}') \
  -o jsonpath='{.config.accessInformation.nfsServerIp}:{.config.accessInformation.nfsPath}{"\n"}'
192.168.0.131:/trident_pvc_dfe8adb5_c1ed_4c60_9532_9addb75bbda6
```

Unmount the VirtioFS view of that directory on **both** guests (keep the ConfigMap share if you want), then mount NFS. Cloud-init already installed `nfs-utils`. Use **`nolock`**: Alpine’s BusyBox `flock` does not support `flock -e`, so `rpc.statd` never starts, and NFSv3 NLM locking then fails with `rpc.statd is not running`. Local locks are enough for this lab. Keep the export on **one line** (a wrap in the middle of `trident_pvc_...` is a different path):  
```bash
# on alpine-vm1 and alpine-vm2
doas umount /mnt/shared
doas mount -t nfs -o nfsvers=3,nolock 192.168.0.131:/trident_pvc_dfe8adb5_c1ed_4c60_9532_9addb75bbda6 /mnt/shared
ls /mnt/shared
cat /mnt/shared/from-vm1.txt
```

Replace the export with **your** `nfsServerIp`:`nfsPath` from the `tvol`.  
If the SVM is only reachable from the nodes and not from the VM overlay, you need a network path (additional NIC, SNAT, or a dedicated LIF the guests can route to). In this lab, guests typically reach `192.168.0.131`.  

Check that you can write a file **without** `doas`. Unlike VirtioFS, NFSv3 talks to ONTAP as the guest UID, so the unprivileged `alpine` user can create files and they stay owned by `alpine`, not remapped to 107:  
```bash
# on alpine-vm1
$ echo "written by alpine-vm1" > /mnt/shared/from-vm1-nfsmount.txt
$ ls -la /mnt/shared
total 9
drwxrwxrwx    2 root     root          4096 Sep  9 14:53 .
drwxr-xr-x    4 root     root          1024 Sep  9 12:20 ..
drwxrwxrwx    2 root     root          4096 Sep  9 11:57 .snapshot
-rw-r--r--    1 alpine   alpine          22 Sep  9 14:53 from-vm1-nfsmount.txt
-rw-r--r--    1 qemu     qemu            22 Sep  9 13:43 from-vm1.txt
-rw-r--r--    1 qemu     qemu            22 Sep  9 13:59 from-vm2.txt
```
The `from-vm*.txt` files still show as `qemu:qemu` because that is UID/GID 107 from virtiofsd; a guest that never created that user would still print `107 107`.  
`ls -la` also shows ONTAP’s hidden `.snapshot` directory on the export. That is the volume’s Snapshot copies (read-only, useful for a quick in-guest restore). The VirtioFS mount of the same PVC does not give you this view.  

**Pros**
- Native NFS locking, permissions, and ONTAP features (export policy, QoS, snapshots of that volume).  
- Live migration is just “the VM moved, the NFS server did not”: no VirtioFS daemon to migrate.  
- Same pattern you would use on VMware, bare metal, or a VM outside Kubernetes.  
- SMB/CIFS to ONTAP is the Windows equivalent (not labbed here).

**Cons**
- Guest must have an NFS/SMB client and IP reachability to the SVM (not only to the pod network).  
- You are no longer going through the PVC mount in virt-launcher; Kubernetes does not see the guest I/O as a volumeMount (the PVC still maps to the same export if you keep it).  
- Two VMs plus a Pod all writing with different UID schemes still need a permission plan (root_squash / no_root_squash, etc.).  
- You could also create a **dedicated SVM export** not tied to a PVC; then KubeVirt/Trident are out of the data path entirely.

For a fair comparison, remount VirtioFS afterwards if you continue to section E:  
```bash
doas umount /mnt/shared
doas mount -t virtiofs shared-fs /mnt/shared
```

## E. Shareable RWX block disk

KubeVirt can attach the **same block PVC** to several VMs if the disk is marked `shareable: true`.  
That tells QEMU not to take an exclusive writer lock. It is the “shared LUN” model, not a shared folder.

Stop the VirtioFS VMs (keep the boot DataVolumes) and create the shareable pair plus a new iSCSI RWX PVC:  
```bash
$ kubectl -n share delete vm alpine-vm1 alpine-vm2
virtualmachine.kubevirt.io "alpine-vm1" deleted
virtualmachine.kubevirt.io "alpine-vm2" deleted

$ kubectl create -f shared_block_pvc.yaml
persistentvolumeclaim/shared-block created

$ kubectl create -f alpine_vm1_shareable.yaml -f alpine_vm2_shareable.yaml
virtualmachine.kubevirt.io/alpine-vm1 created
virtualmachine.kubevirt.io/alpine-vm2 created
```

On each guest, the extra disk is typically `/dev/vdb` (boot is `vda`, cloud-init may be `vdc`).  
The KubeVirt documentation demo writes **raw bytes**, not a filesystem:  
```bash
# alpine-vm1
$ lsblk
NAME MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda  253:0    0   1G  0 disk /
vdb  253:16   0   1G  0 disk
vdc  253:32   0   1M  0 disk

$ printf "Test awesome shareable disks" | doas dd of=/dev/vdb bs=1 count=150 conv=notrunc
28+0 records in
28+0 records out
28 bytes (28B) copied, 0.010926 seconds, 2.5KB/s

# alpine-vm2
$ doas dd if=/dev/vdb bs=1 count=32 conv=notrunc
Test awesome shareable disks
```

**Pros**
- Lowest-level sharing: clustered databases, clustered filesystems, SCSI-persistent-reservation style apps.  
- RWX block + `shareable` works across nodes (no podAffinity required). RWO would force both VMs on the same node.  
- Live migration remains realistic: RWX block plus `shareable` keeps both writers on shared storage.

**Cons**
- **Do not** `mkfs.ext4` on that LUN and mount it on both VMs. You will corrupt the filesystem.  
- You need GFS2, OCFS2, or an application that talks to the raw device. That is out of scope for this lab.  
- Operationally heavier than “a folder of files”.  
- Same Trident iSCSI LUN: fine for this demo, painful if you actually wanted NAS semantics.

## F. Sequential sharing (hotplug the same PVC)

If you only need VM-A then VM-B to see the same disk **at different times** (for example a data disk you move during a maintenance window), you do not need any of the concurrent methods.

That is the [secondary disks](../2_SecondaryDisks/) chapter: `virtctl addvolume` / `removevolume` (or a declarative hotplug).  
**Pros:** simple, any RWO disk, no clustered FS, no VirtioFS.  
**Cons:** not concurrent; downtime or unmount on the donor VM; easy to forget `fstab` on the receiver.

## G. What should you pick?

- **Configuration, certs, a few files owned by Kubernetes:** VirtioFS + ConfigMap/Secret.  
- **Shared POSIX directory between VMs (and Pods) on this platform:** VirtioFS + Trident NFS PVC.  
- **Shared directory and you care about NAS features (real locking, per-user UIDs, export policies) more than VirtioFS:** in-guest NFS or SMB to ONTAP.  
- **Clustered application that wants a LUN:** shareable RWX block + clustered FS or app-level locking.  
- **One disk, many owners, but never at the same time:** hotplug.

VirtioFS of a **hostPath** directory is omitted on purpose. It pins VMs to a node, fights SELinux, and skips Trident. If you need node-local scratch, that is not “sharing between VMs”.
