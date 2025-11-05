#########################################################################################
# SCENARIO 15: Dude, where is my PVC?
#########################################################################################

When creating a PVC against a storage class, the volume will be created using one backend corresponding to that storage class.  
If multiple backends fit, how do you make sure the volume ends up where you want?  
This can be done by adding _parameters_ (ie _filters_) to the storage class definition.  
Also, is that maintainable at scale, when you add more backends later down the road?  

Moreover, if you built a Kubernetes cluster that spans over multiple zones, how do you control the exact localisation of your volumes?  

We will explore in this chapter multiple ways to control PVC placement:  
- [1.](./1_Filters_and_Selectors/) Filters and selectors. 
- [2.](./2_CSI_Topology/) CSI Topology  

If you have not yet read the [Addenda08](../../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario15_pull_images.sh* to pull images utilized in this scenario if needed:  
```bash
sh scenario15_pull_images.sh
```