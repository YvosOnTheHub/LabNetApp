#########################################################################################
# ADDENDA 14: How to upgrade the Kubernetes cluster
#########################################################################################

**GOAL:**  
Upgrades can only be done from one _minor_ version to the next.  
This addenda will give you the step by step commands to run, but keep in mind this is only for this lab... If you were to upgrade in a real environment, more care would need to be taken.

The upgrade of Kubernetes is mostly required for [Scenario13](../../Trident_Scenarios/Scenario13/2_CSI_VolumeGroupSnapshots), which introduces the **Volume Group Snapshot** feature (Beta in Kubernetes 1.32). This addenda only upgrades the cluster. Enabling the Volume Group Snapshot feature gate is done later in that scenario.

The following links were used to build this chapter:

- Upgrade from 1.29 to 1.30: https://v1-30.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/  
- Upgrade from 1.30 to 1.31: https://v1-31.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Upgrade from 1.31 to 1.32: https://v1-32.docs.kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/


**Time to do some upgrades !**

- [1.29 to 1.30](upgrade_to_1.30)
- [1.30 to 1.31](upgrade_to_1.31)
- [1.31 to 1.32](upgrade_to_1.32)

Or go back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp).
