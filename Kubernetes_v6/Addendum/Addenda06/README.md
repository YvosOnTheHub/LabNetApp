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
NAME                                  READY   STATUS    RESTARTS        AGE
trident-controller-85574d7d77-74tls   6/6     Running   0               3h11m
trident-node-linux-fmp72              2/2     Running   0               3h11m
trident-node-linux-fqbnj              2/2     Running   0               3h11m
trident-node-linux-tsvfm              2/2     Running   1 (3h10m ago)   3h11m
trident-node-linux-vcslx              2/2     Running   0               3h11m
trident-node-windows-lfj2g            3/3     Running   1 (3h10m ago)   3h11m
trident-node-windows-ppsvc            3/3     Running   1 (3h10m ago)   3h11m
trident-operator-5c4f8bd896-l5xh4     1/1     Running   0               3h14m
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
This is achievable with the tool call _tmux_ which is already part of the lab.  

To run it, simply enter _tmux_.  
From there you can use the following shortcuts to manage your workplaces:  
- Ctrl+b %: vertical split
- Ctrl+b ": horizontal split
- Ctrl+b o: switching between terminals

More information can be found here:
https://www.linuxcloudvps.com/blog/install-and-use-tmux-on-centos/


## D. KREW

Kubernetes is a lot about CLI & Kubectl will quickly become your best friend.  
You may some time reach kubectl's limits & start building your own shortcuts or scripts to get the information you are looking for.  
Krew is a Kubernetes plugin management tool that can become pretty handy. Plenty of plugins are already available to display resources, secrets, usage & much more.  
You can find some information about Krew on this link: https://krew.sigs.k8s.io/

Let's install it & run it:  
```bash
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

You can then use the _kubectl krew search_ to list all the available plugins & _kubectl krew install_ command to install a specific one.  
Here are a few I have tested:  
- **get-all**: will display all the objects of a namespace (ie many more than with _kubectl get -A_)
- **view-utilization**: displays CPU/RAM utilization of the cluster
- **rbac-view**: graphical view of all RBAC configured on the cluster, with a filter feature
- **tree**: displays a hierarchical view of some objects (ex: deployment => replicaset => pod)
- **view-secret**: decyphers & displays a secret (faster than running jsonpath + base64)