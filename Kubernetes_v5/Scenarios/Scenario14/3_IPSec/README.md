#########################################################################################
# SCENARIO 14.3: IPSec
#########################################################################################  

IPSec is a protocol used to estrablish authenticated communication between environments over IP, as well as encryption of the packets.  
It is fairly simple to install & configure, both on the Kubernetes hosts and in the ONTAP platform.  

We will see in the chapter how to implement IPSec in this Lab, through Ansible playbooks.  

The `hosts` ansible file has been prepared to contain the source & destination network configuration, as well as a key.  
Any key would work. However, you could use the following command to generate one for your tests (careful with the '/' character):
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
$ ping 192.168.0.211
PING 192.168.0.211 (192.168.0.211) 56(84) bytes of data.
^C
--- 192.168.0.211 ping statistics ---
8 packets transmitted, 0 received, 100% packet loss, time 6999ms
```bash

```bash
$ charon-systemd &
[1] 5634

$ swanctl --load-all
loaded ike secret 'ike-pol_rhel7_nfs_client'
no authorities found, 0 unloaded
no pools found, 0 unloaded
loaded connection 'pol_rhel7_nfs_client'
successfully loaded 1 connections, 0 unloaded
```






cluster1::> sec ipsec policy show
  (security ipsec policy show)
        Policy                                           Cipher
Vserver Name       Local IP Subnet    Remote IP Subnet   Suite          Action
------- ---------- ------------------ ------------------ -------------- -------
svm_secured
        ipsec_k8s  192.168.0.211/32   192.168.0.63/24    SUITEB_GCM256  ESP_TRA



