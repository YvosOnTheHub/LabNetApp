#########################################################################################
# ADDENDA 8: Install K1S
#########################################################################################

I found K1S useful when you want to follow the state of some resources in a specific namespaces.  
For instance, in the [scenario11](../../Scenarios/Scenario11), where we use statefulsets, you can follow the creation of each POD & each PVC.  

More information here: https://github.com/weibeld/k1s.  
One of dependencies include JQ.  

```bash
cd
wget https://raw.githubusercontent.com/weibeld/k1s/master/k1s
chmod +x k1s
mv k1s /usr/local/bin
```

Finally, to launch the program & follow the evolution of the creation of pod in a namespace (ex: _mysql_), you can simply type _k1s mysql pods_

```bash
$ k1s mysql pods
 ____ ____ ____
||k |||1 |||s ||  Kubernetes Dashboard
||__|||__|||__||  Namespace: mysql
|/__\|/__\|/__\|  Resources: pods

mysql-0 Running
mysql-1 NonReady
```
