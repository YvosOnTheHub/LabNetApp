#########################################################################################
# ADDENDA 14: How to upgrade the Kubernetes cluster
#########################################################################################

**GOAL:**  
Upgrades can only be done from one _minor_ version to the next.  
This addenda will give you the step by step commands to run, but keep in mind this is only for this lab... If you were to upgrade in a real environment, more care would need to be taken.

The upgrade de Kubernetes 1.19 is mostly required for the [Scenario20](../../../Scenarios/Scenario20) which describes the Generic Ephemeral Volumes feature, introduced in this version. The upgrade procedure includes different steps to enable this new feature.  

The following links were used to build this chapter:

- Upgrade from 1.18 to 1.19: https://v1-19.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  

**Time to do some upgrades !**

- [1.18 to 1.19](upgrade_to_1.19)

Or go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp).