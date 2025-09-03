#########################################################################################
# SCENARIO 14.3: IPSec
#########################################################################################  

IPSec is a protocol used to estrablish authenticated communication between environments over IP, as well as encryption of the packets.  
It is fairly simple to install & configure, both on the Kubernetes hosts and in the ONTAP platform.  

We will see in the chapter how to implement IPSec in this Lab, through Ansible playbooks.  

The `hosts` ansible file has been prepared to contain the source & destination network configuration, as well as a key.  
Any key would work. However, you could use the following command to generate one for your tests (careful with the '/' character you may find in the key):
```bash
openssl rand -base64 24
```

Let's configure IPSec on the SVM, followed by the configuration on the Kubernetes hosts. I chose the 'Strongswan' implementation for this example, granted there are other solutions out there
```bash
$ ansible-playbook svm_secured_ipsec.yaml
PLAY [localhost]
TASK [Gathering Facts]
TASK [config IPSec for ONTAP] 
TASK [config IPSec policy for ONTAP]

PLAY [kubernetes]
TASK [Gathering Facts]
TASK [install and configure IPSec on all kubernetes nodes]
TASK [ipsec-host-config : ipsec-config | Install Packages] 
TASK [ipsec-host-config : ipsec-config | Copy swanctl.conf template] 

PLAY RECAP 
localhost                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel1                      : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel2                      : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
rhel3                      : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

At this point, IPSec is configured on both the storage environment & the hosts, however it is not yet activated on the Kubernetes nodes.  
This can be validated by running a ping against the NFS interface, which should fail:
```bash
$ ping 192.168.0.231
PING 192.168.0.231 (192.168.0.231) 56(84) bytes of data.
^C
--- 192.168.0.231 ping statistics ---
8 packets transmitted, 0 received, 100% packet loss, time 6999ms
```

As IPsec has only been configured for the NFS LIF, ping should still work for the SVM Management interface:
```bash
$ ping 192.168.0.230
PING 192.168.0.230 (192.168.0.230) 56(84) bytes of data.
64 bytes from 192.168.0.230: icmp_seq=1 ttl=64 time=0.385 ms
64 bytes from 192.168.0.230: icmp_seq=2 ttl=64 time=0.215 ms
^C
--- 192.168.0.230 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1000ms
rtt min/avg/max/mdev = 0.215/0.300/0.385/0.085 ms
```

We can also validate that IPSec has been enabled on the ONTAP backend:
```bash
$ ssh cluster1 -l admin security ipsec policy show
        Policy                                           Cipher
Vserver Name       Local IP Subnet    Remote IP Subnet   Suite          Action
------- ---------- ------------------ ------------------ -------------- -------
svm_secured
        ipsec_k8s  192.168.0.231/32   192.168.0.63/25    SUITEB_GCM256  ESP_TRA
```

Strongswan must be executed while the charon-systems deamon is running. Charon implements an IKEv2 daemon (Internet Key Exchange) that establishes secured connections between peers, in our example, between ONTAP on one side & each node of the Kubernetes cluster on the other side.  
The following steps have to be run `on each` kubernetes node: 
```bash
$ charon-systemd &
[1] 5634

$ swanctl --load-all
loaded ike secret 'ike-pol_rhel7_nfs_client'
no authorities found, 0 unloaded
no pools found, 0 unloaded
loaded connection 'pol_rhel7_nfs_client'
successfully loaded 1 connections, 0 unloaded

$ swanctl --list-pols
pol_rhel7_nfs_client/pol_rhel7_nfs_client, TRANSPORT
  local:  192.168.0.0/25
  remote: 192.168.0.231/32

$ swanctl --list-conns
pol_rhel7_nfs_client: IKEv2, no reauthentication, rekeying every 86400s
  local:  192.168.0.63/25
  remote: 192.168.0.231/32
  local pre-shared key authentication:
    id: 192.168.0.0/25
  remote pre-shared key authentication:
    id: 192.168.0.211/32
  pol_rhel7_nfs_client: TRANSPORT, rekeying every 28800s
    local:  192.168.0.0/25
    remote: 192.168.0.231/32
```

Let's try again a ping from the master node to the NFS LIF:
```bash
$ ping 192.168.0.231
PING 192.168.0.231 (192.168.0.231) 56(84) bytes of data.
64 bytes from 192.168.0.231: icmp_seq=2 ttl=64 time=0.301 ms
64 bytes from 192.168.0.231: icmp_seq=3 ttl=64 time=0.262 ms
```

It works !

We can also validate on the ONTAP platform that a SA (Security Association) was established by the IKE protocol.  
If you tested a ping on all the nodes, you should see  
```bash
$ ssh cluster1 -l admin security ipsec show-ikesa -node cluster1-01 -vserver svm_secured
            Policy Local           Remote
Vserver     Name   Address         Address         Initator-SPI     State
----------- ------ --------------- --------------- ---------------- -----------
svm_secured ipsec_k8s
                   192.168.0.231   192.168.0.61    5a5a7bd429e7b6d1 ESTABLISHED
                   192.168.0.231   192.168.0.62    96f1e32c4d5bb14f ESTABLISHED
                   192.168.0.231   192.168.0.63    a580a161ef832b07 ESTABLISHED
```

## What's next

You shoud continue with:  
- [Trident Configuration](../4_Trident_Configuration): Let's use Trident on the secured storage tenant  

Or go back to:  
- the [Scenario14 FrontPage](../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)


<!--
to check the Replay window value, use the following

$ ip xfrm state show
src 192.168.0.62 dst 192.168.0.231
        proto esp spi 0xc07e682a reqid 1 mode transport
        replay-window 0
        aead rfc4106(gcm(aes)) 0x8a632ee6f75b886c38a465362659e72101edfaf42f64dfc06da61635ddfd27c30e54868a 128
        lastused 2025-08-18 14:28:37
        anti-replay context: seq 0x0, oseq 0x15e8, bitmap 0x00000000
        sel src 192.168.0.62/32 dst 192.168.0.231/32
src 192.168.0.231 dst 192.168.0.62
        proto esp spi 0xc7464b34 reqid 1 mode transport
        replay-window 0
        aead rfc4106(gcm(aes)) 0xe76f14d7bc3423a9c673da3af711a6c9cf0df90cea1171cb667e8ad29c6393359e371486 128
        lastused 2025-08-18 14:28:37
        anti-replay context: seq 0x0, oseq 0x0, bitmap 0x00000000
        sel src 192.168.0.231/32 dst 192.168.0.62/32
-->