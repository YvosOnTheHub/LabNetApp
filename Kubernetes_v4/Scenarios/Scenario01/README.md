#########################################################################################
# SCENARIO 1: Trident upgrade to 20.10
#########################################################################################

**GOAL:**  
This scenario is intended to see how easy it is to upgrade Trident.

Currently, Trident 20.07.1 is installed in this lab:

```bash
$ kubectl get tver
NAME      VERSION
trident   20.07.1
```
  
Starting with Trident 20.04, there are 2 ways to deploy Trident:  
[1.](1_Operator) Using Trident's Operator, introduced in 20.04  
2. Using the _legacy_ way, via _tridentctl_  

This scenarion focuses on the Operator only.  
If one of you requires a traditional installation with _tridentctl_, please open an issue on github.