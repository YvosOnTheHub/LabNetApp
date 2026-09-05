#########################################################################################
# SCENARIO 13: Application-consistent snapshots of a database inside a KubeVirt VM
#########################################################################################

Scenario 11 showed how to protect an Alpine Virtual Machine with Trident Protect (snapshot, restore, failover).  
This scenario goes one step further: the VM hosts a **minimal MariaDB** on a second disk, and Trident Protect uses **pre/post snapshot hooks** so the snapshot is **application-consistent**, not only crash- or filesystem-consistent.

Alpine is kept on purpose. It is lightweight and already used in this lab. MariaDB runs with a tiny InnoDB buffer so the VM stays at **1 vCPU / 1Gi**.

First of all, you need to install & configure KubeVirt on the primary cluster.  
Please refer to the [Addenda15](../../Addendum/Addenda15/) to do so.  
Scenario 11 is a useful warm-up if you have never created an Alpine VM in this lab.

## What this demo proves

Trident Protect 24.10.1 and later can **freeze/unfreeze the guest filesystem** via the QEMU guest agent (`NEPTUNE_VM_FREEZE`). That makes the snapshot **filesystem-consistent**.

A database also needs **quiesce** (`FLUSH TABLES WITH READ LOCK`) **before** that freeze. That is done with ExecHooks:

1. **Pre snapshot hook** (ExecHook)  
   Runs in the `virt-launcher` **compute** container.  
   Uses `virsh qemu-agent-command` → `guest-exec` to run `/usr/local/bin/db-hook.sh pre` **inside the VM**.
2. **VM filesystem freeze** (Trident Protect, automatic)  
   qemu-guest-agent `fsfreeze`.
3. **CSI snapshot** of the boot and data PVCs.
4. **VM filesystem thaw** (Trident Protect, automatic).
5. **Post snapshot hook** (ExecHook)  
   Same path, `db-hook.sh post`, to release the MariaDB lock.

Do **not** also install a MariaDB script under `/etc/qemu/fsfreeze-hook.d/` if you use these ExecHooks, or the database would be frozen twice.

There are two chapters in this scenario:  
[1.](./1_Setup/) Virtual Machine + MariaDB setup  
[2.](./2_Protection/) Trident Protect application, hooks, snapshot and restore  
