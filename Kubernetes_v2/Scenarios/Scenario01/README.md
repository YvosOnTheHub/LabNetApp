#########################################################################################
# SCENARIO 1: Trident upgrade to 20.07
#########################################################################################

**GOAL:**  
This scenario is intended to see how easy it is to upgrade Trident.  
  
Starting with Trident 20.04, there are 2 ways to deploy Trident:  
[1.](1_Tridentctl) Using the _legacy_ way, via _tridentctl_  
[2.](2_Operator) Using Trident's Operator, introduced in 20.04  

:boom:  
While the Operator was for Green Field environments only with Trident 20.04, it is now also possible to upgrade a non-Operator based CSI Trident with the version 20.07.  
Also, if it your first time playing with Trident, I would recommend going the Operator way directly.  
:boom:  

Also, whatever way you choose to install Trident, the remaining scenarios wont be impacted. They work the same way in both architectures.
