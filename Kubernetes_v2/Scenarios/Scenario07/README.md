#########################################################################################
# SCENARIO 7: Create your first SAN backends 
#########################################################################################

GOAL:  
You understood how to create backends and what they are for.
You probably also created a few ones with NFS drivers.
It is now time to add more backends that can be used for block storage.

![Scenario7](Images/scenario7.jpg "Scenario7")

## A. Create your first SAN backends

You will find in this directory a few backends files.
You can decide to use all of them, only a subset of them or modify them as you wish

Here are the 4 backends & their corresponding driver:
- backend-san-default.json        ONTAP-SAN
- backend-san-eco-default.json    ONTAP-SAN-ECONOMY

```
# tridentctl -n trident create backend -f backend-san-default.json
+-------------+----------------+--------------------------------------+--------+---------+
|    NAME     | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+-------------+----------------+--------------------------------------+--------+---------+
| SAN-default | ontap-san      | ad04f63c-592d-49ae-bfde-21a11db06976 | online |       0 |
+-------------+----------------+--------------------------------------+--------+---------+

# tridentctl -n trident create backend -f backend-san-eco-default.json
+-----------------+-------------------+--------------------------------------+--------+---------+
|      NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+-----------------+-------------------+--------------------------------------+--------+---------+
| SAN_ECO-default | ontap-san-economy | 530f18b1-680b-420f-ad6b-94c96fea84b9 | online |       0 |
+-----------------+-------------------+--------------------------------------+--------+---------+

# kubectl get -n trident tridentbackends
NAME        BACKEND               BACKEND UUID
...
tbe-7nl8v   SAN_ECO-default       530f18b1-680b-420f-ad6b-94c96fea84b9
tbe-wgs99   SAN-default           ad04f63c-592d-49ae-bfde-21a11db06976
...
```

## B. Create storage classes pointing to each new backend

You will also find in this directory a few storage class files.
You can decide to use all of them, only a subset of them or modify them as you wish

```
# kubectl create -f sc-csi-ontap-san.yaml
storageclass.storage.k8s.io/storage-class-san created

# kubectl create -f sc-csi-ontap-san-eco.yaml
storageclass.storage.k8s.io/storage-class-san-economy created
```