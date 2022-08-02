#########################################################################################
# SCENARIO 14: Let's talk about security
#########################################################################################

**GOAL:**  
Most of the scenarios you find in this GitHub are made for end-users, so that they can get a glimpse of what benefits they can get with Trident. Storage parameters are most of the time pretty much open, while I use admin rights.  

This scenario is more aimed for storage admins, so that they can configure secured storage tenants for Kubernetes.  

[Scenario05](../Scenario05) (iSCSI Bidirectional CHAP) & [Scenario12](../Scenario12) (Dynamic Export Policy Management) already presented some security features you could configure directly in Trident. We will now see some tips related to ONTAP.  

We will see here other mechanism to harden the security on the storage backend.  

<p align="center"><img src="Images/scenario14.jpg"></p>

This lab will use some ansible playbooks. Make sure you have installed Ansible & the ONTAP Collection beforehand (cf [Addenda04](../../Addendum/Addenda04)).  

We will also use a dedicated SVM called **svm_secured**.  
Before moving to the different chapters, please run the following command to create the SVM alongside different basic elements (aside from networking).

```bash
$ ansible-playbook svm_secured_create.yaml
...
TASK [Create SVM]
TASK [Create Specific User]
TASK [Enable NFS]
TASK [Create ExportPolicyRule for the default policy]
TASK [Create iSCSI Igroup for Trident]
TASK [Enable iSCSI]

PLAY RECAP
localhost                  : ok=7    changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

You are now ready to move through the 3 different chapters:  
[1.](1_Network_Management) How do I restrict network accesses to specific hosts & needs?  
[2.](2_NFS_Showmount) How do you avoid a malicious listing of available NFS exports  
[3.](3_Trident_Configuration) Let's see the end result
