#########################################################################################
# ADDENDA 4: How to upgrade the Kubernetes cluster
#########################################################################################

**GOAL:**  
Some interesting features require a more recent version than the one you find in this LabOnDemand:

- iSCSI PVC Resizing (introduced with Kubernetes 1.16)
- CSI Snapshots & "Create PVC from Snapshot" (promoted Beta with Kubernetes 1.17)
- CSI Topology (promoted GA with Kubernetes 1.17)

Upgrades can only be done from one _minor_ version to the next. You need to perform two successive upgrades to go from 1.15 to 1.18.  
This addenda will give you the step by step commands to run, but keep in mind this is only for this lab... If you were to upgrade in a real environment, more care would need to be taken.

The following links were used to build this chapter:

- Upgrade from 1.15 to 1.16: https://v1-16.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  
- Upgrade from 1.16 to 1.17: https://v1-17.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  
- Upgrade from 1.17 to 1.18: https://v1-18.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  

Before upgrading to a specific version of Kubernetes, make sure you have upgraded Trident beforehand if you are using the *Tridentctl* installation method [(Scenario 1)](../../Scenarios/Scenario01).  

**Time to do some upgrades !**

- [1.15 to 1.16](upgrade_to_1.16)
- [1.16 to 1.17](upgrade_to_1.17)
- [1.17 to 1.18](upgrade_to_1.18)

Or go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp).