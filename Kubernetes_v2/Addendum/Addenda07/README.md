#########################################################################################
# ADDENDA 7: Install a LoadBalancer
#########################################################################################

Accessing an application in Kubernetes can be achieved in many different ways.  
Here are 2 examples I use in some configurations:

- nodePort: you choose a port (above 30000) that can be accessed with any host IP address of the cluster
- loadBalancer: you set a range of IP addresses that will be assigned to the services of type LoadBalancer

Loads balancers are not implemented by defaut in Kubernetes. You need to install the one you want accross what is available.  
I chose MetalLB for this purpose.  

The range configured for MetalLB is 192.168.0.140 to 192.168.0.149.  
Obviously, if you need more addresses, feel free to upgrade the configMap.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f metallb-configmap.yml
```

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?