#########################################################################################
# SCENARIO 8: Consumption control
#########################################################################################

**GOAL:**  
As Trident dynamically manages persitent volumes & bring lots of goodness to the app level.  
The first benefit is that end-users do not need to rely on a storage admin to provision volumes on the fly.
However, this freedom can lead to quickly feel up the storage backend, especially if the user does not tidy up his environment...  

A good practice is to place some controls to make sure storage is well used.  
We are going to review here different methods to control the storage consumption.

This scenario will guide you through different ways to add control to your environment  
[1.](1_Kubernetes_parameters) Kubernetes parameters  
[2.](2_Trident_parameters) Trident parameters  
[3.](3_ONTAP_parameters) ONTAP parameters  
[4.](4_A_bit_of_everything) Mixing them all  
