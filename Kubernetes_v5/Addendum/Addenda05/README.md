#########################################################################################
# ADDENDA 5: Install a LoadBalancer
#########################################################################################

Accessing an application in Kubernetes can be achieved in many different ways.  
Here are 2 examples I use in some configurations:

- nodePort: you choose a port (above 30000) that can be accessed with any host IP address of the cluster
- loadBalancer: you set a range of IP addresses that will be assigned to the services of type LoadBalancer

Loads balancers are not implemented by defaut in Kubernetes. You need to install the one you want accross what is available.  
I chose MetalLB for this purpose.  

The range configured for MetalLB is 192.168.0.140 to 192.168.0.149.  
Obviously, if you need more addresses, feel free to upgrade the configMap.

If you have not yet read the [Addenda08](../Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory _scenario10_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 parameters, your Docker Hub login & password:

```bash
sh addenda05_pull_images.sh my_login my_password
```

You can now proceed with the installation of MetalLB, granted the manifests need to be updated in order to reflect the use of a private repository.

```bash
wget https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
wget https://raw.githubusercontent.com/google/metallb/v0.9.6/manifests/metallb.yaml
sed -i s,metallb\/,registry.demo.netapp.com\/metallb\/, metallb.yaml
kubectl apply -f namespace.yaml
kubectl apply -f metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f metallb-configmap.yml
```

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?