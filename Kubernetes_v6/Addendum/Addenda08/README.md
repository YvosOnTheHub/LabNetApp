#########################################################################################
# ADDENDA 8: How to run this lab with the Docker hub rate limiting 
#########################################################################################

You may have heard or seen the new rules applied by Docker on the number of images that can be pulled by a user:  
=> https://www.docker.com/increase-rate-limits#:~:text=Anonymous%20and%20Free%20Docker%20Hub,pull%20requests%20per%20six%20hours

In a nutshell:  
- **unauthenticated** users (anonymous) are limited to 100 pull requests per 6 hours (enforced by IP address)
- **free tier Docker users** are limited to 200 pull requests per 6 hours
- a **paid subscription** will give you access to much more

The impact for Lab on Demand users is that they are potentially not going to be able to pull images, ie upgrade Trident (to a version under 25.10) or create an application.  
This chapter will guide you through different steps to manage this situation...  

**Note that Trident 25.10 images are also now available on the Quay repository (https://quay.io/organization/netapp), which does not have the same requirements or limits.** Quay is a repository managed by RedHat.  

After reading this chapter, you will decide if you need to create your own Docker Hub user, which can be done directly on the following link [https://hub.docker.com/]. Obviously, you dont need to create a new user each time you use this lab on demand. This is done once & for all.  

If you only use images that are stored on different repositories, this may not be necesary (for now).  

In order to find out how many Docker Hub pull requests you have, you can find the information [here](1_Pull_Requests).  

Also, you need to understand what triggers an image to be pulled from a repository.  
(cf https://kubernetes.io/docs/concepts/containers/images/).  

In a nutshell, images will be downloaded:  
- If it has never been pulled locally from a repository  
- If the _imagePullPolicy_ is set to _Always_ in the app definition  
- If the image tag _latest_ is used  

Otherwise, if the image is already present, Kubernetes will directly use, which also saves a good precious couple of seconds. :laughing:  
In this case, when looking at the logs of an application, you will see the following:  
```bash
Events:
  Type     Reason                  Age                From                     Message
  ----     ------                  ----               ----                     -------
...
  Normal   Pulled                  41s                kubelet, rhel2           Container image "ghost:2.6-alpine" already present on machine
  Normal   Created                 41s                kubelet, rhel2           Created container blog
  Normal   Started                 41s                kubelet, rhel2           Started container blog
```

Now, let's see what we can do to manage this situation:  
- [be lazy](2_Lazy_Images)  
- [use secrets](3_Secrets)  
- [use a private repository](4_Private_repo)  
- [PREFERRED: use the LoD cache registry](5_LoD_cache)

Most of the scenarios are built with the private repository in mind. That will also reduce the number of images to download from Internet.  
