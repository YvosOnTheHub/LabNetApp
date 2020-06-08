#########################################################################################
# SCENARIO 1: Trident install/upgrade
#########################################################################################

**GOAL:**  
This scenario is intended to see how easy it is to install & upgrade Trident.  
  
Starting with Trident 20.04, there are 2 ways to deploy Trident:  
[1.](1_Tridentctl) Using the _legacy_ way, via _tridentctl_  
[2.](2_Operator) Using Trident's Operator, introduced in 20.04   

Please note that Operator architecture is only for Green Field environments. You cannot upgrade from one method to the next.

Also, whatever way you choose to install Trident, the remaining scenarios wont be impacted. They work the same way in both architectures.