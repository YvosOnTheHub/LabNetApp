#########################################################################################
# ADDENDA 8: Use a Docker login the lazy way !
#########################################################################################

You have seen when images are pulled from repository.  
You then also understand that if an image is already present  Kubernetes is not going to try to retrieve it from a repository.  
(unless the _imagePullPolicy_ parameter or the tag _latest_ are used).

The _lazy_ way consists into 2 steps **on each Kubernetes host**:  
- log into Docker Hub with the command _podman login_
- pull all the images you need for your demos or tests with the command _podman image pull_

Here is a list of some images used in this lab with Trident 25.10.0:
- netapp/trident:25.10.0
- netapp/trident-operator:25.10.0
- netapp/trident-autosupport:25.10.0
- ghost:2.6-alpine
- ghost:3.13-alpine
- mysql:5.7
- busybox:1.35.0

This is more a quick workaround rather than a method you would use in production.  
Have a look at the [next chapter](../3_Secrets) to understand how to work with _secrets_.

You will find in this directory a script called _pull_all_images.sh_ that you can call to download images:
This script will download the whole aforementioned list on a specific host, & uses 3 parameters:  
- Hostname or host IP address
- Docker hub login
- Docker hub password

Example:  
```bash
sh pull_all_images.sh rhel4 my_login my_password
```
