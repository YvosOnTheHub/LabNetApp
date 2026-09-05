#########################################################################################
# SCENARIO 13: Setup — Alpine VM hosting a minimal MariaDB
#########################################################################################

Alpine was chosen because it is lightweight and already used in Scenario 11.  
The VM is sized at **1 vCPU / 1Gi**. That is more than the 128Mi Alpine-only VM, but still small enough for the Lab on Demand. MariaDB is configured with a 32Mi InnoDB buffer pool and `performance_schema=OFF`.

Note there is **no `limits.memory`** on the VM. A limit is enforced on the whole `virt-launcher` pod, not only guest RAM. QEMU overhead and virtio page cache count against it. A limit equal to the 1Gi request leaves no headroom and can crash the VMI (`The VirtualMachineInstance crashed`) during `mariadb-install-db`. Leave the limit unset, as in Scenario 11.

This scenario runs in its own namespace **alpinedb**, so it does not collide with Scenario 11 (`alpine`).

```bash
$ kubectl create ns alpinedb
namespace/alpinedb created
```

## A. Alpine image

For this scenario, let's use the Alpine image packaged in a container, and pushed to the local registry:  
```bash
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman pull quay.io/yvosonthehub/vm/alpine:qcow
podman tag quay.io/yvosonthehub/vm/alpine:qcow registry.demo.netapp.com/kubevirt/alpine:qcow
podman push registry.demo.netapp.com/kubevirt/alpine:qcow
```

## B. Cloud-init (SSH, packages, qemu-guest-agent)

Create an SSH key pair and inject the public key via a secret:  
```bash
ssh-keygen -t rsa -N "" -f /root/.ssh/alpine-db
kubectl create secret generic alpinepub --from-file=key1=/root/.ssh/alpine-db.pub -n alpinedb
```

KubeVirt already exposes a virtio-serial channel for the QEMU guest agent. You still need **qemu-guest-agent inside the guest**, otherwise:  
- Trident Protect cannot freeze the filesystem
- `virsh qemu-agent-command` / `guest-exec` from the virt-launcher pod will fail

```bash
kubectl create secret generic alpine-cloudinit-userdata -n alpinedb --from-literal=userdata="#cloud-config
users:
  - name: alpine
    ssh_authorized_keys:
      - $(kubectl get secret alpinepub -n alpinedb -o jsonpath='{.data.key1}' | base64 -d)
chpasswd:
  expire: false
ssh_pwauth: True
runcmd:
  - echo alpine:alpine | chpasswd
  - echo '################################################' > /etc/motd
  - echo 'Alpine + MariaDB on KubeVirt / Trident Protect' >> /etc/motd
  - echo '################################################' >> /etc/motd
  - apk add --no-cache lsblk parted mariadb mariadb-client qemu-guest-agent udev
  - rc-update add udev sysinit
  - echo 'GA_PATH=\"/dev/virtio-ports/org.qemu.guest_agent.0\"' > /etc/conf.d/qemu-guest-agent
  - rc-update add qemu-guest-agent default
  - rc-service qemu-guest-agent start
"
```

## C. Virtual Machine creation

The VM manifest comes with a Load balancer service that you can use to connect with SSH.  
This can be useful, as the IP address of the VMI can change when the VM reboots or changes host.  

```bash
$ kubectl create -f alpine_vm.yaml
virtualmachine.kubevirt.io/alpine-db-vm created
```

Wait until the VM is Ready, then connect:  
```bash
virtctl console alpine-db-vm -n alpinedb
```

Or with SSH:  
```bash
ALPINE_LB_IP=$(kubectl get svc -n alpinedb alpine-vm-ssh-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && echo $ALPINE_LB_IP
alias sshalpdb='ssh alpine@$ALPINE_LB_IP -i /root/.ssh/alpine-db -o ServerAliveInterval=10 -o ServerAliveCountMax=3'
sshalpdb
```
If the IP address was already referenced as a SSH host, you will need to first remove it from the list of known hosts:  
```bash
ssh-keygen -R $ALPINE_LB_IP -f /root/.ssh/known_hosts
```

Confirm the guest agent is connected from the cluster:  
```bash
kubectl get vmi -n alpinedb alpine-db-vm -o jsonpath='{.status.conditions[?(@.type=="AgentConnected")].status}{"\n"}'
```
This should print `True`. An empty line means the `AgentConnected` condition is missing: the guest agent is installed but **not running**. `rc-update add` only enables the service for later boots; cloud-init must also `rc-service qemu-guest-agent start` on first boot.

If the VM is already up, start it once:  
```bash
doas rc-service qemu-guest-agent start
```

## D. Data disk + MariaDB (inside the VM)

Alpine uses **doas**, not sudo. The data disk is raw (`vdb`) and must be partitioned, formatted and mounted on `/data`:

```bash
echo -e "o\nn\np\n1\n\n\nw" | doas fdisk /dev/vdb
doas mkfs.ext4 /dev/vdb1
doas mkdir /data
doas mount /dev/vdb1 /data
doas chmod 777 /data
UUID=$(doas blkid -s UUID -o value /dev/vdb1) && echo "UUID=$UUID   /data   ext4   defaults   0 0" | doas tee -a /etc/fstab
```

Install MariaDB with a tiny footprint and store the datadir on the **data** disk:  
```bash
doas mkdir -p /data/mysql
doas chown mysql:mysql /data/mysql

cat << 'EOF' | doas tee /etc/my.cnf.d/demo.cnf
[mysqld]
datadir=/data/mysql
socket=/run/mysqld/mysqld.sock
bind-address=127.0.0.1
skip-name-resolve
performance_schema=OFF
innodb_buffer_pool_size=32M
innodb_log_file_size=8M
max_connections=10
table_open_cache=32
log_error=/data/mysql/mariadb.err
EOF

# Alpine's packaged OpenRC unit starts mysqld_safe but the pidfile is mariadbd's.
# OpenRC then waits 50s, reports failure, and status stays "stopped" even though
# the database is up. Run mariadbd directly so the pidfile matches.
cat << 'EOF' | doas tee /etc/init.d/mariadb
#!/sbin/openrc-run

name="MariaDB"
command="/usr/bin/mariadbd"
command_user="mysql"
command_background=true
pidfile="/run/mysqld/mariadb.pid"
# Everything else comes from /etc/my.cnf.d/demo.cnf.
# Do not pass --pid-file: OpenRC writes the pidfile itself.
command_args=""

depend() {
	need localmount
}

start_pre() {
	checkpath --directory --owner mysql:mysql --mode 0775 /run/mysqld
}

start_post() {
	ewaitfile 30 /run/mysqld/mysqld.sock
}
EOF
doas chmod 755 /etc/init.d/mariadb

doas mariadb-install-db --user=mysql --datadir=/data/mysql
# Ignore: resolveip cannot look up alpine-db-vm.alpinedb.svc.cluster.local
# Ignore: copy support-files/mariadb.service — Alpine uses OpenRC, not systemd
# Wait until the bootstrap server is gone, then enable and start via OpenRC.
while pgrep -f '[m]ariadbd' >/dev/null; do sleep 1; done
doas rc-update add mariadb default
doas rc-service mariadb start
doas rc-service mariadb status
# expect: status: started

doas mariadb -e "CREATE DATABASE demo;"
doas mariadb -e "CREATE TABLE demo.t1 (id INT AUTO_INCREMENT PRIMARY KEY, comment VARCHAR(40), ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
doas mariadb -e "INSERT INTO demo.t1(comment) VALUES ('seed');"
doas mariadb -e "SELECT * FROM demo.t1;"
```

The packaged init script starts `mysqld_safe` but the pidfile is `mariadbd`'s. OpenRC waits 50s for a process name that never matches, reports failure, and `rc-service mariadb status` stays `stopped` even though the database is up. The replacement init script above runs `mariadbd` directly.


## E. In-guest freeze script

Copy `db-hook.sh` into the VM and make it executable:

```bash
# from the lab jumphost (rhel3)
ALPINE_LB_IP=$(kubectl get svc -n alpinedb alpine-vm-ssh-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
scp -i /root/.ssh/alpine-db \
  ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario13/1_Setup/db-hook.sh \
  alpine@$ALPINE_LB_IP:/tmp/db-hook.sh
ssh -i /root/.ssh/alpine-db alpine@$ALPINE_LB_IP 'doas mv /tmp/db-hook.sh /usr/local/bin/db-hook.sh && doas chmod 755 /usr/local/bin/db-hook.sh'
```

Smoke-test the script **inside the VM** before wiring Trident Protect:

```bash
doas /usr/local/bin/db-hook.sh pre
doas mariadb -e "SHOW PROCESSLIST;"
# you should see a SLEEP holding the read lock
doas /usr/local/bin/db-hook.sh post
```

## F. Remove the cloud-init disk

Same requirement as Scenario 11: leave the cloud-init disk attached and snapshot restore / failover can fail because the secret may not be there on restore.

```bash
kubectl -n alpinedb patch vm alpine-db-vm --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/domain/devices/disks/2"},
  {"op": "remove", "path": "/spec/template/spec/volumes/2"}
]'
virtctl restart alpine-db-vm -n alpinedb
```

Wait for the VM to come back, then check that `vdc` is gone, `/data` is mounted, MariaDB is running, qemu-guest-agent is `AgentConnected`, and `/usr/local/bin/db-hook.sh` is still present.

You can now proceed with [Trident Protect protection](../2_Protection/).
