#########################################################################################
# ADDENDA 5: Prepare your ONTAP Backend for Block Storage
#########################################################################################

**GOAL:**  
The ONTAP environment in the lab on demand is not setup for block storage just yet.
You can choose to update the SVM you are already using, or create your own.

In this scenario, I will just update the current SVM with the following parameters
- iSCSI Data LIF: 192.168.0.140
- iSCSI iGroup: trident

if you feel confortable with ONTAP, you can create the environment by yourself.
Otherwise, you can use some scripting methods...

One way to do so would be to use Ansible roles.
You can inspire yourself with the lab https://github.com/YvosOnTheHub/LabAnsible if you like.

To make it simple, you will find here the different commands to run via SSH.
Open Putty, connect to "cluster1" and finally enter all the following:

```
vserver modify -vserver svm1 -allowed-protocols nfs,iscsi
lun igroup create -igroup trident -protocol iscsi -ostype linux -vserver svm1
net interface create -vserver svm1 -lif svm1_iscsi -data-protocol iscsi -home-node cluster1-01 -home-port e0d -address 192.168.0.140 -netmask 255.255.255.0 -firewall-policy data
vserver iscsi create -target-alias svm1 -vserver svm1
```


## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?