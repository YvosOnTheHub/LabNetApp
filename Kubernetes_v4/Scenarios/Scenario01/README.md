#########################################################################################
# SCENARIO 1: Trident upgrade to 21.01
#########################################################################################

**GOAL:**  
This scenario is intended to see how easy it is to upgrade Trident.

Currently, Trident 20.07.1 is installed in this lab:

```bash
$ kubectl get tver -n trident
NAME      VERSION
trident   20.07.1
```

Let's first download the version you would like to install:

```bash
cd
mkdir 21.01.1
cd 21.01.1
wget https://github.com/NetApp/trident/releases/download/v21.01.1/trident-installer-21.01.1.tar.gz
tar -xf trident-installer-21.01.1.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/
```

:mag:  
*A* **resource** *is an endpoint in the Kubernetes API that stores a collection of API objects of a certain kind; for example, the built-in pods resource contains a collection of Pod objects.*  
*A* **custom resource** *is an extension of the Kubernetes API that is not necessarily available in a default Kubernetes installation. It represents a customization of a particular Kubernetes installation. However, many core Kubernetes functions are now built using custom resources, making Kubernetes more modular.*  
:mag_right:  

Trident 20.10 introduced the support of the **CSI Topology** feature which allows the administrator to manage a location aware infrastructure.  
However, there are 2 requirements for this to work:

- You need at least Kubernetes 1.17 (:heavy_check_mark:!)  
- Somes labels (region & zone) need to be added to the Kubernetes nodes before Trident is installed.

If you are planning on testing this feature (cf [Scenario15](../Scenario15)), make sure these labels are configured before upgrading Trident.  

```bash
$ kubectl get nodes -o=jsonpath='{range .items[*]}[{.metadata.name}, {.metadata.labels}]{"\n"}{end}' | grep "topology.kubernetes.io"
[rhel1, map[beta.kubernetes.io/arch:amd64 beta.kubernetes.io/os:linux kubernetes.io/arch:amd64 kubernetes.io/hostname:rhel1 kubernetes.io/os:linux topology.kubernetes.io/region:trident topology.kubernetes.io/zone:west]]
[rhel2, map[beta.kubernetes.io/arch:amd64 beta.kubernetes.io/os:linux kubernetes.io/arch:amd64 kubernetes.io/hostname:rhel2 kubernetes.io/os:linux topology.kubernetes.io/region:trident topology.kubernetes.io/zone:east]]
[rhel3, map[beta.kubernetes.io/arch:amd64 beta.kubernetes.io/os:linux kubernetes.io/arch:amd64 kubernetes.io/hostname:rhel3 kubernetes.io/os:linux node-role.kubernetes.io/master: topology.kubernetes.io/region:trident topology.kubernetes.io/zone:admin]]
```

If they are not, you can create them with the following commands:

```bash
# LABEL "REGION"
kubectl label node rhel1 "topology.kubernetes.io/region=trident"
kubectl label node rhel2 "topology.kubernetes.io/region=trident"
kubectl label node rhel3 "topology.kubernetes.io/region=trident"

# LABEL "ZONE"
kubectl label node rhel1 "topology.kubernetes.io/zone=west"
kubectl label node rhel2 "topology.kubernetes.io/zone=east"
kubectl label node rhel3 "topology.kubernetes.io/zone=admin"
```

Last, if you have not yet read the [Addenda09](../../Addendum/Addenda09) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in the Scenario01 directory _scenario01_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh scenario01_pull_images.sh my_login my_password
```

Now, it's time to proceed with the installation of Trident :trident:!  

Currently with the version 21.01, there are 3 ways to install Trident:  
[1.](1_Operator) Using Trident's Operator, introduced in 20.04  
[2.](2_Helm) Using Helm to install Trident's operator, method introduced in 21.01  
3. Using the _legacy_ way, via _tridentctl_  (not detailed here)
