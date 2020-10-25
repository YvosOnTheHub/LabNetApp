#########################################################################################
# SCENARIO 15.3: Trident configuration
#########################################################################################  

[root@rhel3 3_Trident_Configuration]# trident create backend -f backend-svm_secured-NFS.json
+-----------------+----------------+--------------------------------------+--------+---------+
|      NAME       | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+-----------------+----------------+--------------------------------------+--------+---------+
| SVM_Secured_NFS | ontap-nas      | ceccc4de-8837-441b-94d1-7a4b165b7984 | online |       0 |
+-----------------+----------------+--------------------------------------+--------+---------+
[root@rhel3 3_Trident_Configuration]# trident create backend -f backend-svm-secured-iSCSI.json
+-------------------+----------------+--------------------------------------+--------+---------+
|       NAME        | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+-------------------+----------------+--------------------------------------+--------+---------+
| SVM_Secured_iSCSI | ontap-san      | 08346ec3-0c9b-4b74-a964-14fbb6aca65c | online |       0 |
+-------------------+----------------+--------------------------------------+--------+---------+


[root@rhel3 3_Trident_Configuration]# kc -f sc-svm-secured-nas.yaml
storageclass.storage.k8s.io/sc-svm-secured-nas created
[root@rhel3 3_Trident_Configuration]# kc -f sc-svm-secured-san.yaml
storageclass.storage.k8s.io/sc-svm-secured-san created
[root@rhel3 3_Trident_Configuration]# kg sc
NAME                          PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-svm-secured-nas            csi.trident.netapp.io   Delete          Immediate           true                   39s
sc-svm-secured-san            csi.trident.netapp.io   Delete          Immediate           true                   31s



