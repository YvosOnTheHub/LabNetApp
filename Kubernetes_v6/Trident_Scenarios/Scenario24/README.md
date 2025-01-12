#########################################################################################
# SCENARIO 24: Mirroring volumes
#########################################################################################

Trident 24.06.1 brought you the mirroring feature.  
A user can now manage the snapmirror relationships directly in Kubernetes, via a new object called _TridentMirrorRelationship_.  
This gives you multiple opportunities such as (for example):  
- configure a disaster recovery plan between 2 Kubernetes clusters, for the data only.  
- migrate volumes between 2 ONTAP systems.  

A TMR can have 3 states:  
- _promoted_: the PVC is ReadWrite & mountable  
- _established_: the local PVC is part of a new SnapMirror relationship  
- _reestablished_: the local PVC is part of a preexisting SnapMirror  

This scenario will take you through both examples (DR & migration).  
As this lab only has one ONTAP cluster, we will configure the mirroring between 2 SVMs.  
Mirroring volumes between 2 ONTAP clusters can be done following the same methods.  

Scenario global requirement:  
- Ansible is used for part of the configuration: [Addenda04](../../Addendum/Addenda04/)  
- A new SVM is also needed to host the secondary volume: [Addenda13](../../Addendum/Addenda13/)  

There is a script in this folder to go through those 2 requirements: _setup_sc24_svm.sh_.  

Know that Trident does not take care of the peering configuration.  
The storage admin must perform this task beforehand.  

Most of the time, peering & mirroring will happen between 2 ONTAP clusters. In this lab, we will configure mirroring between 2 SVM.  
This configuration is done via Ansible in this scenario:  
```bash
$ ansible-playbook svm_peering.yaml
PLAY [Create SVM Peering] 
TASK [Gathering Facts] 
TASK [Create vserver peer] 
PLAY RECAP 
localhost                  : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Last, if you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario24_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario24_pull_images.sh
```

Time to dig into what we can do with Trident:  
[1.](1_Volume_DR) Disaster recovery  
[2.](2_Volume_Migration) Volume Migration  