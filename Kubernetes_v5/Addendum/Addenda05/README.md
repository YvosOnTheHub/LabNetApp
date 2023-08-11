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

MetalLB images are located in the Quay repository and do not require any logging.  

MetalLB will be installed as a Helm chart.  
In older versions, the configuration was written in ConfigMaps. There are now located in specific CRD.  

```bash
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace -f metallb-values.yaml
```
Once all the PODs are up&running, you can proceed with configuration:
```bash
$ kubectl get -n metallb-system deploy
NAME                 READY   UP-TO-DATE   AVAILABLE   AGE
metallb-controller   1/1     1            1           2m26s

$ kubectl apply -f metallb-ipaddresspool.yaml
ipaddresspool.metallb.io/metallb-cidr created
$ kubectl apply -f metallb-l2advert.yaml
l2advertisement.metallb.io/l2advertisement created
```

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?