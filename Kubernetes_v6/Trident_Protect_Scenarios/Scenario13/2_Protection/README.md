#########################################################################################
# SCENARIO 13: Protection — consistent snapshot of a DB inside a VM
#########################################################################################

This chapter protects the Alpine VM with Trident Protect, using ExecHooks so MariaDB is quiesced **before** the CSI snapshot.

Trident Protect 24.10.1+ already freezes the guest filesystem via qemu-guest-agent. Leave that enabled. The ExecHooks add **application** consistency on top.

## A. Manual test of the virt-launcher hook (do this first)

The ExecHook does **not** run inside MariaDB. It runs in the **compute** container of `virt-launcher`, then talks to qemu-ga:  
```
Trident Protect ExecHook
  → virt-launcher / compute
    → virsh qemu-agent-command guest-exec
      → /usr/local/bin/db-hook.sh  (inside the VM)
```

Copy `virt-launcher-hook.sh` into the virt-launcher pod and run it once:  
```bash
HOOKDIR=~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario13/2_Protection
VMPOD=$(kubectl get pod -n alpinedb -l kubevirt.io=virt-launcher,vm.kubevirt.io/name=alpine-db-vm -o jsonpath='{.items[0].metadata.name}') && echo $VMPOD

kubectl cp $HOOKDIR/virt-launcher-hook.sh alpinedb/${VMPOD}:/tmp/virt-launcher-hook.sh -c compute
kubectl exec -n alpinedb ${VMPOD} -c compute -- chmod +x /tmp/virt-launcher-hook.sh
kubectl exec -n alpinedb ${VMPOD} -c compute -- virsh -c qemu:///session list --name
kubectl exec -n alpinedb ${VMPOD} -c compute -- /tmp/virt-launcher-hook.sh pre
```

The command `virsh -c qemu:///session list --name` talks to this pod’s user-session libvirt. That line is a reachability check for libvirt inside the virt-launcher pod, before you run the real hook. It should return `alpinedb_alpine-db-vm`.  

In another SSH session to the VM, `SHOW PROCESSLIST` should show `SLEEP` and a new `INSERT` should **block**. Then:  
```bash
kubectl exec -n alpinedb ${VMPOD} -c compute -- /tmp/virt-launcher-hook.sh post
```

The INSERT should complete. If `guest-exec` is rejected, qemu-ga may be blocking that RPC. Confirm `guest-ping` first. The domain lookup must run **inside** the container, so wrap the whole command in `sh -c`. Otherwise your jumphost tries to run `virsh` and fails with `command not found`:  
```bash
kubectl exec -n alpinedb ${VMPOD} -c compute -- sh -c \
  'D=$(virsh -c qemu:///session list --name | head -1); virsh -c qemu:///session qemu-agent-command "$D" "{\"execute\":\"guest-ping\"}"'
```
Expected output is {"return":{}}, which means qemu-guest-agent is reachable.

## B. Trident Protect application

Use the VM-scoped selector so Trident Protect collects the VirtualMachine and its dependent resources (PVCs, DataVolumes, virt-launcher, secrets):  
```bash
$ tridentctl-protect create app alpinedb --virtual-machines 'alpinedb(alpine-db-vm)' -n alpinedb
Application "alpinedb" created.

$ tridentctl-protect get app alpinedb -n alpinedb
+----------+------------+-------+-----+
|   NAME   | NAMESPACES | STATE | AGE |
+----------+------------+-------+-----+
| alpinedb | alpinedb   | Ready | 7s  |
+----------+------------+-------+-----+
```

An AppVault is required for snapshot metadata. If you do not have one yet, follow [Scenario03](../../Scenario03/). The examples below use **ontap-vault**.

## C. Pre / post snapshot ExecHooks

Create the hooks from the script on disk (preferred) **or** from the YAML manifests in this folder (they embed the same script as `hookSource`).

CLI:  
```bash
$ tridentctl-protect create exechook mysql-snap-pre --app alpinedb --action snapshot --stage pre \
  --source-file virt-launcher-hook.sh --arg pre \
  --match 'podLabel:kubevirt.io=virt-launcher' \
  --match 'containerName:compute' -n alpinedb
ExecHook "mysql-snap-pre" created.

$ tridentctl-protect create exechook mysql-snap-post --app alpinedb --action snapshot --stage post \
  --source-file virt-launcher-hook.sh --arg post \
  --match 'podLabel:kubevirt.io=virt-launcher' \
  --match 'containerName:compute' -n alpinedb
ExecHook "mysql-snap-post" created.
```

YAML:  
```bash
kubectl create -f mysql-hook-pre-snap.yaml -f mysql-hook-post-snap.yaml
```

```bash
$ tridentctl-protect get exechook -n alpinedb
+-----------------+----------+-------------------------------------+----------+-------+---------+-------+-----+
|      NAME       |   APP    |                MATCH                |  ACTION  | STAGE | ENABLED | ERROR | AGE |
+-----------------+----------+-------------------------------------+----------+-------+---------+-------+-----+
| mysql-snap-post | alpinedb | podLabel:kubevirt.io=virt-launcher; | Snapshot | Post  | true    |       | 17s |
|                 |          | containerName:compute               |          |       |         |       |     |
| mysql-snap-pre  | alpinedb | podLabel:kubevirt.io=virt-launcher; | Snapshot | Pre   | true    |       | 53s |
|                 |          | containerName:compute               |          |       |         |       |     |
+-----------------+----------+-------------------------------------+----------+-------+---------+-------+-----+
```

>> The pre-hook holds `FLUSH TABLES WITH READ LOCK` until the post-hook runs.  
>> During that window, writes to MariaDB wait. That is the demo: the snapshot is taken while the DB cannot accept writes.

## D. On-demand snapshot

Optional: in a second SSH session, generate continuous writes:  
```bash
i=1
while true; do
  doas mariadb -e "INSERT INTO demo.t1(comment) VALUES ('live-$i');"
  i=$((i+1))
  sleep 1
done
```

Create the snapshot:  
```bash
$ tridentctl-protect create snapshot alpinedbsnap1 --app alpinedb --appvault ontap-vault -n alpinedb
Snapshot "alpinedbsnap1" created.
```

Wait until it is Completed. The writer session should stall during the freeze, then resume after the post-hook. That stall is the long gap in `ts` (often ~20s). The first INSERT that completes after the gap is **after** the snapshot.  
```bash
$ tridentctl-protect get snapshot -n alpinedb
$ kubectl get exechooksrun -n alpinedb
```

You should also see one VolumeSnapshot per PVC:  
```bash
kubectl get vs -n alpinedb
```

## E. Break the database, then restore

When no snapshot is running:  
```bash
doas mariadb -e "DROP DATABASE demo;"
doas mariadb -e "SHOW DATABASES;"
```

Restore to a **new** namespace (simplest live check; the VM is not stopped on the source):  
```bash
$ kubectl create ns alpinedbsr
namespace/alpinedbsr created

$ tridentctl-protect create sr alpinedbsr1 --namespace-mapping alpinedb:alpinedbsr \
  --snapshot alpinedb/alpinedbsnap1 -n alpinedbsr
SnapshotRestore "alpinedbsr1" created.

$ tridentctl-protect get sr -n alpinedbsr
+-------------+-------------+-----------+-------+-----+
|    NAME     |  APPVAULT   |   STATE   | ERROR | AGE |
+-------------+-------------+-----------+-------+-----+
| alpinedbsr1 | ontap-vault | Completed |       | 20s |
+-------------+-------------+-----------+-------+-----+
```

When the restored VM is Ready:

```bash
virtctl console alpine-db-vm -n alpinedbsr
```

The VMI address is the masquerade IP (`10.0.2.2`) and is not reachable from rhel3. Recreate the SSH LoadBalancer in the restore namespace (it is not a VM disk, so it is not in the snapshot):

```bash
kubectl -n alpinedbsr create -f- <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alpine-vm-ssh-lb
spec:
  type: LoadBalancer
  selector:
    vm.kubevirt.io/name: alpine-db-vm
  ports:
  - name: ssh
    port: 22
    targetPort: 22
    protocol: TCP
EOF
ALPINE_LB_IP_SR=$(kubectl get svc -n alpinedbsr alpine-vm-ssh-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ssh-keygen -R $ALPINE_LB_IP_SR -f /root/.ssh/known_hosts
ssh alpine@$ALPINE_LB_IP_SR -i /root/.ssh/alpine-db
```

The custom OpenRC unit and `/usr/local/bin/db-hook.sh` live on the boot disk, so they come back with the restore. `doas rc-service mariadb status` should be `started`. First boot can still take a few extra seconds while InnoDB runs crash recovery (the datadir was snapshotted live). Then:  
```bash
doas mariadb -e "SHOW DATABASES;"
doas mariadb -e "SELECT * FROM demo.t1;"
```

The `demo` database and the rows captured **before** the freeze should be back.

Read the timestamps, not the id numbers, to see where the freeze sat. The writer loop is ~2s per row. A ~20s gap is the lock window. The first row **after** that gap was blocked until the post-hook; it committed on the source only after the snapshot, so it must **not** appear on the restore. Example: `live-19` at `09:25:55` then `live-20` at `09:26:15` means the snapshot ends at `live-19`. `live-20` on the source is the first write after thaw.

In-place restore (`tridentctl-protect create sir`) is also supported, but the running VM must be stopped first so the PVCs can be replaced. Prefer the clone restore for the demo.

## F. Notes

- Do not add a MariaDB script under `/etc/qemu/fsfreeze-hook.d/` while these ExecHooks are enabled.
- If you change `virt-launcher-hook.sh`, recreate the ExecHooks (or update `hookSource`) so Trident Protect uses the new script.
- After a VM restart, the virt-launcher **pod name** changes; the ExecHook match is by **label** (`kubevirt.io=virt-launcher`), so you do not need to edit the hook.
- Non-root virt-launcher (KubeVirt default) speaks `qemu:///session`, not `qemu:///system`. The hook tries session first, then system. Manual `virsh` checks should use `qemu:///session`.
- `db-hook.sh` lives on the **boot** disk (`/usr/local/bin`). It is included in the snapshot. The restored VM can freeze again without recopying the script.
- First boot of a restored VM can take a few extra seconds for InnoDB crash recovery. Confirm with `doas mariadb -e "SHOW DATABASES;"`.

<!-- NOTES

# Copy hook into virt-launcher
VMPOD=$(kubectl get pod -n alpinedb -l kubevirt.io=virt-launcher,vm.kubevirt.io/name=alpine-db-vm -o jsonpath='{.items[0].metadata.name}')
kubectl cp ./virt-launcher-hook.sh alpinedb/${VMPOD}:/tmp/virt-launcher-hook.sh -c compute

# ExecHooksRun match messages
kubectl get exechooksrun -n alpinedb -o custom-columns='NAME:.metadata.name,APP:.spec.applicationRef,STATE:.status.state,MATCHES:.status.conditions[0].message'

# Cleanup
kubectl delete ns alpinedb alpinedbsr

-->
