#########################################################################################
# SCENARIO 1: Trident upgrade to 23.07.1
#########################################################################################

**GOAL:**  
This scenario is intended to see how easy it is to upgrade Trident.

Currently, Trident 21.10.0 is installed in this lab:

```bash
$ kubectl get tver -n trident
NAME      VERSION
trident   21.10.0
```

Let's first download the version you would like to use.  
Technically, if you decide to install Trident with Helm, you would not even need to perform this step, however throughout this lab, we will use the binary _tridentctl_ a few times, so we still to download it.

```bash
cd
mkdir 23.07.1 && cd 23.07.1
wget https://github.com/NetApp/trident/releases/download/v23.07.1/trident-installer-23.07.1.tar.gz
tar -xf trident-installer-23.07.1.tar.gz
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
$ kubectl get nodes --label-columns topology.kubernetes.io/region,topology.kubernetes.io/zone
NAME    STATUS   ROLES    AGE     VERSION   REGION    ZONE
rhel1   Ready    <none>   263d    v1.22.3   trident   west
rhel2   Ready    <none>   263d    v1.22.3   trident   east
rhel3   Ready    master   263d    v1.22.3   trident   admin
```

If they are not, you can create them with the following commands:  
```bash
# LABEL "REGION"
kubectl label node rhel1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/region=east" --overwrite

# LABEL "ZONE"
kubectl label node rhel1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node rhel3 "topology.kubernetes.io/zone=east1" --overwrite
```

Astra Trident now strictly enforces the use of multipathing configuration in SAN environments, with a recommended value of `find_multipaths: no` in _multipath.conf_ file.

Use of non-multipathing configuration or use of `find_multipaths: yes` or `find_multipaths: smart` value in multipath.conf file will result in mount failures. Trident has recommended the use of `find_multipaths: no` since the 21.07 release.  

As multipathing is disabled in this lab, please run the following on each of the Kubernetes nodes to enable it:
```bash
sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
mpathconf --enable --with_multipathd y --find_multipaths n
systemctl enable --now multipathd
```

The iSCSI SVM of this lab only comes with one Data LIF. In order to comply with the dual path requirement, let's create another Data LIF: 
```bash
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "ip": { "address": "192.168.0.140", "netmask": "24" },
  "location": {
    "home_port": {
      "name": "e0d",
      "node": { "name": "cluster1-01" }
    }
  },
  "name": "iscsi_svm_iscsi_02",
  "scope": "svm",
  "service_policy": { "name": "default-data-blocks" },
  "svm": { "name": "iscsi_svm" }
}' "https://cluster1.demo.netapp.com/api/network/ip/interfaces" 
```

Let's check that our SVM now has 3 LIFs (2 Data LIF & 1 Mgmgt LIF):  
```bash
$ curl -s -X GET -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" "https://cluster1.demo.netapp.com/api/network/ip/interfaces?svm.name=iscsi_svm" | jq -r .records[].name
iscsi_svm_iscsi_02
iscsi_svm_iscsi_01
iscsi_svm_admin_lif1
```

Last, if you have not yet read the [Addenda08](../../Addendum/Addenda08) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in the Scenario01 directory _scenario01_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 optional parameters, your Docker Hub login & password:

```bash
sh scenario01_pull_images.sh my_login my_password
```

Now, it's time to proceed with the installation of Trident :trident:!  

Currently with the version 23.07, there are 4 ways to install Trident:  
[1.](1_Operator) Using Trident's Operator, introduced in 20.04  
[2.](2_Helm) Using Helm to install Trident's operator, method introduced in 21.01  
[3.] Using the _legacy_ way, via _tridentctl_  (not detailed here)  
[4.] Using a CD tool such as ArgoCD (check out [Scenario18](../Scenario18))  
