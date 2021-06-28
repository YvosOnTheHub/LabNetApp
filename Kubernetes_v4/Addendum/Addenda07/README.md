#########################################################################################
# ADDENDA 7: Install cool tools
#########################################################################################

When playing with Kubernetes or Unix, you can always find new tools that improve your daily job.  
Here are a few that I found interesting:

- K8SH (Kubernetes shell)
- K1S (Simple Kubernetes Dashboard)
- TMUX (Terminal Multiplexer)

## A. K8SH

I found K8SH to be pretty useful, as it allows to easily navigate through your favorite kubectl commands without explicitly write the namespace all the time.  
Also, it tells in in which context you are, which can also be good to have.  

More information here: https://github.com/Comcast/k8sh  
You will find there:

- how to install this shell
- how to manage contexts & namespaces
- all the available shortcuts (ex: _pods_ stands for _kubectl get pods_)  

To accomodate the current Putty configuration, we also need to change some colors.  

```bash
cd
git clone https://github.com/Comcast/k8sh.git
mv k8sh/k8sh /usr/bin/
sed -e '/  NAMESPACE_COLOR.*/ s/CYAN/BLUE/' -i /usr/bin/k8sh
sed -e '/  PS_NAMESPACE_COLOR.*/ s/CYAN/BLUE/' -i /usr/bin/k8sh
sed -e '/  PS_CONTEXT_COLOR.*/ s/LRED/RESTORE/' -i /usr/bin/k8sh
```

Finally, to launch the program, you can simply type _k8sh_

```bash
$ k8sh
Initializing...
k8sh_init; exec </dev/tty

Welcome to k8sh
Sourcing in ~/.bash_profile...
Gathering current kubectl state...
Making aliases...
For k completion please install bash-completion
Sourcing in ~/.k8sh_extensions...

Context: kubernetes-admin@kubernetes
Namespace: default
(kubernetes-admin@kubernetes/default) ~ $
```

There you go! A quick example now, let's change namespace & list the pods:

```bash
(kubernetes-admin@kubernetes/default) ~ $ ns
default
kube-node-lease
kube-public
kube-system
monitoring
snapshot-controller
tigera-operator
trident

(kubernetes-admin@kubernetes/default) ~ $ ns trident

(kubernetes-admin@kubernetes/trident) ~ $ pods
NAME                                READY   STATUS    RESTARTS   AGE
trident-csi-676dd87bc6-2825p        6/6     Running   0          3d9h
trident-csi-j67xc                   2/2     Running   0          3d9h
trident-csi-vdvqp                   2/2     Running   0          3d9h
trident-csi-xhsfc                   2/2     Running   0          3d9h
trident-operator-67448748f7-sbwvc   1/1     Running   0          3d9h
```


## B. K1S

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

## C. TMUX

I often need to open several Putty windows in parallel, maybe one to work on a project, another one to monitor what's going on.  
This may lead to having many windows open at the same time. If you want to simplify this, you could use one single windows cut in several environments.  
This is achievable with the tool call _tmux_.

To install it, it's pretty straightforward:

```bash
yum install -y tmux
```

& To run it, simply enter _tmux_.  
From there you can use the following shortcuts to manage your workplaces:

- Ctrl+b %: vertical split
- Ctrl+b ": horizontal split
- Ctrl+b o: switching between terminals

More information can be found here:
https://www.linuxcloudvps.com/blog/install-and-use-tmux-on-centos/
