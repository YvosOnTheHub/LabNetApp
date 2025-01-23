#########################################################################################
# SCENARIO 7: Be selective
#########################################################################################  

Defining a Trident Protect appication can be done in multiple ways.  
The most common one would be to do so at the namespace level in order to protect every single object.  
That way, you can restore everything (in-place or somewhere else) or filter on the resources you need.  

Filtering resources upon restore is covered in the first part of this chapter: [Selective Restore](./1-SelectiveRestore/)

However, with more complex applications, you may want to apply different protection rules to sub-elements of a namespace.  
This can be achieved by setting labels on the groups of resources to protect.  
That method is also useful when you only want to protect the data (the persistent volume claim).  

Selecting resources when creating a Trident Protect applicaiton is covered in the second part: [Selective Application](./2-SelectiveApp/).  
