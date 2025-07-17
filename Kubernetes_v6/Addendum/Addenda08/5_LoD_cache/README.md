#########################################################################################
# ADDENDA 8: Use a the LoD pull-through cache
#########################################################################################

The Lab on Demand FAQ states that you can use the LoD cache (_dockreg.labs.lod.netapp.com_) to pull images from the Docker Hub.  
The benefit from this method is that you do not need to create a personal account on the Docker site.  

There are 2 ways to use that method:  
- You need to modify all the hosts that need to pull images from the Docker Hub.  
- In order to save time (and maybe add my sustainability touch), I usually modify the main node (RHEL3) to pull images from the Docker Hub and then push them to the local private registry (_registy.demo.netapp.com_). From that point, my applications will only pull the necesary images from that local registry.  

On the host _RHEL3_ (or all the hosts if you prefer the first method), you need to add the following lines to the _/etc/containers/registries.conf_ file:  
```bash
[[registry]]
prefix = "docker.io"
location = "docker.io"
[[registry.mirror]]
prefix = "docker.io"
location = "dockreg.labs.lod.netapp.com"
```
With that configuration, each time you try to pull an image on RHEL3 from _docker.io_, you will pass through the mirror.  

You will find in this folder, a shell script (_push_trident_images_to_repo.sh_) that will do the following for you:  
- modify the registries.conf file on RHEL3  
- pull the Trident 25.06 images  
- push these images to the local registry (registry.demo.netapp.com)  