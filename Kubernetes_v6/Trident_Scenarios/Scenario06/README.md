#########################################################################################
# SCENARIO 6: Create your first Block Apps
#########################################################################################

**GOAL:**  
Now that the admin has configured Trident to host block workloads (cf [Scenario05](../Scenario05/)), let's see how users would create applications with block volumes. Let's use the same unix app as in the Scenario04, the web server Ghost.  

If you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario06_pull_images.sh* to pull images utilized in this scenario if needed:  
```bash
sh scenario06_pull_images.sh
```

As this lab is configured to serve both iSCSI & NVMe workloads, you will see in this chapter both protocols:  
- [iSCSI](1_iSCSI): Create an application that mounts an iSCSI LUN  
- [iSCSI with LUKS](2_iSCSI_LUKS): Create an application that mounts an encrypted iSCSI LUN  
- [NVMe over TCP](3_NVMe): Create an application that mounts a NVMe namespace  

You can also go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp).