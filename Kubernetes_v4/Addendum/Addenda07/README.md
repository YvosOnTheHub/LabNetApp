#########################################################################################
# ADDENDA 7: Install K8SH
#########################################################################################

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
