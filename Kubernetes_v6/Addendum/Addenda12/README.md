#########################################################################################
# Addenda 12: Create a second Kubernetes cluster
#########################################################################################  

The lab comes with 5 unix hosts, two of them being turned off.  
You can very well use them to create a second Kubernetes cluster, which is useful for some demos, especially those involving mirroring.  
The first step is to activate those 2 hosts (_rhel4_ & _rhel5_).  

This page will give you the method to create this cluster, with _rhel5_ being the master node.  

An _all_in_one.sh_ script can be found in this folder, you can use it to perform all the following steps in one shot.  
If you have cloned the github repo on _rhel3_, you can transfer this file to _rhel5_ using the command (from _rhel3_):
```bash
scp -p /root/LabNetApp/Kubernetes_v6/Addendum/Addenda12/all_in_one.sh rhel5:
```

## A. Kubernetes cluster creation  

Let's follow the same method used to create the first cluster.  
All the requirements are already met & the tools download, you can directly proceed with the creation on the host _rhel5_:  
```bash
kubeadm init --pod-network-cidr=192.168.20.0/21
```
Once done, you need to specify where to access the Kubeconfig file:
```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
echo 'KUBECONFIG=$HOME/.kube/config' >> $HOME/.bashrc
source ~/.bashrc
```
Also, as we are building a small cluster, we also want the control plane to host user applications:  
```bash
$ kubectl taint nodes rhel5 node-role.kubernetes.io/control-plane-
node/rhel5 untainted
```

Let's check the status of the cluster:  
```bash
$ kubectl get node -o wide
NAME    STATUS     ROLES           AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                              KERNEL-VERSION                 CONTAINER-RUNTIME
rhel5   NotReady   control-plane   104s   v1.29.4   192.168.0.65   <none>        Red Hat Enterprise Linux 9.3 (Plow)   5.14.0-362.24.1.el9_3.x86_64   cri-o://1.30.0
```
It is not yet _Ready_ as there is no Pod network configured.  

## B. Pod network configuration  

Calico will be used here for this topic.  
As this product uses images hosted on the Docker Hub, you may need to download them first.  
Luckily, they are already in the lab local registry, so just need to pull them on both nodes (_rhel4_ & _rhel5_):  
```bash
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman pull -q registry.demo.netapp.com/calico/typha:v3.27.3
podman pull -q registry.demo.netapp.com/calico/pod2daemon-flexvol:v3.27.3
podman pull -q registry.demo.netapp.com/calico/cni:v3.27.3
podman pull -q registry.demo.netapp.com/calico/csi:v3.27.3
podman pull -q registry.demo.netapp.com/calico/kube-controllers:v3.27.3
podman pull -q registry.demo.netapp.com/calico/node:v3.27.3
podman pull -q registry.demo.netapp.com/calico/node-driver-registrar:v3.27.3
podman pull -q registry.demo.netapp.com/calico/apiserver:v3.27.3

podman tag registry.demo.netapp.com/calico/typha:v3.27.3 docker.io/calico/typha:v3.27.3
podman tag registry.demo.netapp.com/calico/pod2daemon-flexvol:v3.27.3 docker.io/calico/pod2daemon-flexvol:v3.27.3 
podman tag registry.demo.netapp.com/calico/cni:v3.27.3 docker.io/calico/cni:v3.27.3
podman tag registry.demo.netapp.com/calico/csi:v3.27.3 docker.io/calico/csi:v3.27.3
podman tag registry.demo.netapp.com/calico/kube-controllers:v3.27.3 docker.io/calico/kube-controllers:v3.27.3
podman tag registry.demo.netapp.com/calico/node:v3.27.3 docker.io/calico/node:v3.27.3
podman tag registry.demo.netapp.com/calico/node-driver-registrar:v3.27.3 docker.io/calico/node-driver-registrar:v3.27.3
podman tag registry.demo.netapp.com/calico/apiserver:v3.27.3 docker.io/calico/apiserver:v3.27.3
```
Once done, you can proceed with Calico's installation:  
```bash
mkdir calico && cd calico
wget https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/tigera-operator.yaml
kubectl create -f tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/custom-resources.yaml
sed -i '/^\s*cidr/s/: .*$/: 192.168.20.0\/21/' custom-resources.yaml
sed -i '/^\s*encapsulation/s/: .*$/: VXLAN/' custom-resources.yaml
kubectl create -f ./custom-resources.yaml
```
Let's check that the operator is running:
```bash
$ kubectl get pods -n tigera-operator
NAME                               READY   STATUS    RESTARTS   AGE
tigera-operator-6bfc79cb9c-5hnd8   1/1     Running   0          10s
```
Once done, the Kubernetes node will become _Ready_:  
```bash
$ kubectl get node -o wide
NAME    STATUS   ROLES           AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                              KERNEL-VERSION                 CONTAINER-RUNTIME
rhel5   Ready    control-plane   5m41s   v1.29.4   192.168.0.65   <none>        Red Hat Enterprise Linux 9.3 (Plow)   5.14.0-362.24.1.el9_3.x86_64   cri-o://1.30.0
```

One last parameter to modify:  
```bash
kubectl patch installation default --type=merge -p='{"spec": {"calicoNetwork": {"bgp": "Disabled"}}}'
```

## C. Add a second node to the cluster  

We are now ready to scale the cluster.  
You can retrieve the command on the control plane:  
```bash
$ kubeadm token create --print-join-command
kubeadm join 192.168.0.65:6443 --token 5e2wb3.vgnkb7bxk8znchf9 --discovery-token-ca-cert-hash sha256:70fb9521fc43f8d2e67f4b03d2c9aba2dad0a3ccbfd382f807e44abd5e2d918f
```
You can just copy & paste it on the second host _rhel4_.  
Once done, let's check what we have on the control plane:    
```bash
$ kubectl get node -o wide
NAME    STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                              KERNEL-VERSION                 CONTAINER-RUNTIME
rhel4   Ready    <none>          45s   v1.29.4   192.168.0.64   <none>        Red Hat Enterprise Linux 9.3 (Plow)   5.14.0-362.24.1.el9_3.x86_64   cri-o://1.30.0
rhel5   Ready    control-plane   31m   v1.29.4   192.168.0.65   <none>        Red Hat Enterprise Linux 9.3 (Plow)   5.14.0-362.24.1.el9_3.x86_64   cri-o://1.30.0
```

Magnifique !

Now let's continue with extra stuff.  

## D. Install Helm

```bash
$ wget https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz
$ tar -xvf helm-v3.15.3-linux-amd64.tar.gz
$ cp -f linux-amd64/helm /usr/local/bin/
$ helm version --short
v3.15.3+g3bb50bb
```

## E. Install and configure MetalLB  

Let's use Helm to install this Load Balancer:  
```bash
mkdir ~/metallb && cd ~/metallb
cat << EOF > metallb-values.yaml
  controller:
    image:
      repository: registry.demo.netapp.com/metallb/controller
      tag: v0.14.5
      
  speaker:
    image:
      repository: registry.demo.netapp.com/metallb/speaker
      tag: v0.14.5
    frr:
      enabled: false
EOF

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace -f metallb-values.yaml
```
Let's check the installation:  
```bash
$ kubectl get -n metallb-system po -o wide
NAME                                  READY   STATUS    RESTARTS   AGE   IP             NODE    NOMINATED NODE   READINESS GATES
metallb-controller-78dc79f5d5-5n5hb   1/1     Running   0          65s   192.168.18.2   rhel4   <none>           <none>
metallb-speaker-d84pm                 1/1     Running   0          65s   192.168.0.65   rhel5   <none>           <none>
metallb-speaker-qdk2f                 1/1     Running   0          65s   192.168.0.64   rhel4   <none>           <none>
```
Last, we need to provide a range that will be used to automatically assign IP addresses.  
```bash
cat << EOF > metallb-lab-ipaddresspool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.220-192.168.0.229
EOF

cat << EOF > metallb-l2advert.yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
   - first-pool
EOF

$ kubectl create -f metallb-lab-ipaddresspool.yaml
ipaddresspool.metallb.io/first-pool created
$ kubectl create -f metallb-l2advert.yaml
l2advertisement.metallb.io/l2advertisement created
```

## F. Install Trident

Last, let's install Trident on this cluster.  
I will not describe here how to configure it, this will be covered in the scenarios that use this addenda.  
Also, it is here expected that the current Trident installation already runs at least the version 24.06.1 (which introduced snapmirror support).  
If not done yet, check out the [Scenario01](../../Scenarios/Scenario01/1_Helm/).  
```bash
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
helm install trident netapp-trident/trident-operator --version 100.2410.0 -n trident --create-namespace \
--set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:24.10.0 \
--set operatorImage=registry.demo.netapp.com/trident-operator:24.10.0 \
--set tridentImage=registry.demo.netapp.com/trident:24.10.0 \
--set tridentSilenceAutosupport=true
```
After a few minutes, Trident should be ready:
```bash
$ kubectl get -n trident po -o wide
NAME                                 READY   STATUS    RESTARTS   AGE     IP             NODE    NOMINATED NODE   READINESS GATES
trident-controller-7cc4fb549-9rj5t   6/6     Running   0          2m7s    192.168.18.5   rhel4   <none>           <none>
trident-node-linux-4wrkc             2/2     Running   0          2m7s    192.168.0.65   rhel5   <none>           <none>
trident-node-linux-ws6ff             2/2     Running   0          2m7s    192.168.0.64   rhel4   <none>           <none>
trident-operator-5c4f8bd896-rf8xp    1/1     Running   0          5m20s   192.168.18.3   rhel4   <none>           <none>

$ kubectl get tver -A
NAMESPACE   NAME      VERSION
trident     trident   24.10.1
```

## G. Copy the KUBECONFIG file on the RHEL3

Easier to manage commands locally (on _rhel3_), so let's copy the new cluster's kubeconfig file:  
```bash
curl -s --insecure --user root:Netapp1! -T /root/.kube/config sftp://rhel3/root/.kube/config_rhel5
```
From the host _rhel3_, you will have to use the _--kubeconfig=_ parameter to apply manifests against the second cluster.  

& voilà !