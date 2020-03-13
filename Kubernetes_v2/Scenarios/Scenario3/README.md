################################################################################
# SCENARIO 3: Create your first backends for Trident & Storage Classes for Kubernetes
################################################################################

GOAL:

Trident needs to know where to create volumes.
This information sits in objects called backends. It basically contains:
- the driver type (there currently are 10 different drivers available)
- how to connect to the driver (IP, login, password ...)
- some default parameters

For additional information, please refer to:
- https://netapp-trident.readthedocs.io/en/stable-v20.01/kubernetes/deploying.html#create-and-verify-your-first-backend 
- https://netapp-trident.readthedocs.io/en/stable-v20.01/kubernetes/operations/tasks/backends/index.html 

Once you have configured backend, the end user will create PVC against Storage Classes.
A storage class contains the definition of what an app can expect in terms of storage, defined by some properties (access, media, driver ...)

For additional information, please refer to:
- https://netapp-trident.readthedocs.io/en/stable-v20.01/kubernetes/concepts/objects.html#kubernetes-storageclass-objects

Also, installing & configuring Trident + creating Kubernetes Storage Classe is what is expected to be done by the Admin.

## A. Create your first backends

You will find in this directory a few backends files.
You can decide to use all of them, only a subset of them or modify them as you wish

Here are the 4 backends & their corresponding driver:
- backend-nas-default.json        ONTAP-NAS
- backend-nas-eco-default.json    ONTAP-NAS-ECONOMY
- backend-san-default.json        ONTAP-SAN
- backend-san-eco-default.json    ONTAP-SAN-ECONOMY

```
tridentctl -n trident create backend -f backend-nas-default.json
tridentctl -n trident create backend -f backend-nas-eco-default.json
tridentctl -n trident create backend -f backend-san-default.json
tridentctl -n trident create backend -f backend-san-eco-default.json
```

## B. Create storage classes pointing to each backend

You will also find in this directory a few storage class files.
You can decide to use all of them, only a subset of them or modify them as you wish

```
kubectl create -f sc-csi-ontap-nas.yaml
kubectl create -f sc-csi-ontap-nas-eco.yaml
kubectl create -f sc-csi-ontap-san.yaml
kubectl create -f sc-csi-ontap-san-eco.yaml
```