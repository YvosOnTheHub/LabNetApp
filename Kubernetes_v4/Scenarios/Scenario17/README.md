#########################################################################################
# SCENARIO 17: How to configure HAProxy between Trident & ONTAP
#########################################################################################

Some of you may not allow direct management access between Kubernetes & ONTAP. However, a proxy can be configured between both layers to redirect traffic.  
The [Addenda11](../../Addendum/Addenda11) guides you through the installation of HAProxy. We will here see how to continue its configuration to accept Trident Management flows to access ONTAP.  

As Trident communicates with ONTAP through HTTPS, we will first need to create a certificate (self-signed in this example).  
HAProxy requires both the key & the certificate to be concatenated into a single .pem file.  

```bash
mkdir ~/haproxycert
cd ~/haproxycert
openssl genpkey -algorithm RSA -out privkey.pem
openssl req -new -x509 -key privkey.pem -out selfcert.pem -days 366
cat selfcert.pem privkey.pem > haproxy.pem
```

HAProxy works with _frontends_ (entry point, ie Trident=>HAProxy) and _backends_ (exit point, ie HAProxy=>ONTAP).  
All requests coming on port 8443 (in this example) will be forwarded to the SVM Management Interface.

```bash
$ cat <<EOT >> /etc/haproxy/haproxy.cfg

frontend tridentnashttp
  bind *:8443 ssl crt ~/haproxycert/haproxy.pem
  default_backend ontapnashttp

backend ontapnashttp
  server ontapnashttp 192.168.0.135:443 check ssl verify none
EOT
```

We can now restart HAProxy & check that the new configuration has been taken into account.

```bash
$ systemctl restart haproxy

$ netstat -aon | grep -e 8443 

$ more /var/log/haproxy.log | grep nashttp
Mar 10 12:15:44 rhel3 haproxy[30134]: Proxy tridentnashttp started.
Mar 10 12:15:44 rhel3 haproxy[30134]: Proxy ontapnashttp started.

$ netstat -aon | grep -e 8443 
tcp        0      0 0.0.0.0:8443            0.0.0.0:*               LISTEN      off (0.00/0/0)
```

Let's configure a new Trident Backend & a new storage class, so that we can test this setup.  
If you take a look a the backend json file, you will notice that its management LIF parameter points to **192.168.0.63:8443**, which is the port that HAProxy listens onto, and not **192.168.0.135** which is the SVM IP address.  

```bash
$ tridentctl -n trident create backend -f backend-nas-proxy.json
+-----------+----------------+--------------------------------------+--------+---------+
|   NAME    | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+-----------+----------------+--------------------------------------+--------+---------+
| NAS_Proxy | ontap-nas      | 32184025-2a78-4d26-a9ab-ae96486e3fc3 | online |       0 |
+-----------+----------------+--------------------------------------+--------+---------+

$ kubectl create -f sc-proxy.yaml
storageclass.storage.k8s.io/sc-proxy created
```

Finally, let's create a volume

```bash
$ kubectl create -f pod-with-pvc-proxy.yaml
persistentvolumeclaim/pvc-proxy created
pod/centos-proxy created

$ kubectl get pvc,pod -o wide
NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/pvc-proxy   Bound    pvc-9aef101a-8c3f-4a3c-be88-2e3de9b231b5   5Gi        RWX            sc-proxy       34s

NAME               READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod/centos-proxy   1/1     Running   0          76s   192.168.24.74   rhel3   <none>           <none>

$ kubectl exec pod/centos-proxy -- df /data
Filesystem                                                    1K-blocks  Used Available Use% Mounted on
192.168.0.132:/proxy_pvc_9aef101a_8c3f_4a3c_be88_2e3de9b231b5   5242880   192   5242688   1% /data
```

There you go, operation successful. Also, the volume is mounted directly as you can see (DataLIP IP address 192.168.0.132).
Let's take a look at the logs

```bash
$ tail -f /var/log/haproxy.log
... 192.168.0.61:33718 [11/Mar/2021:15:03:58.248] tridentnashttp~ ontapnashttp/ontapnashttp 2/0/1/42/45 200 451 - - ---- 1/1/0/1/0 0/0 "POST /servlets/netapp.servlets.admin.XMLrequest_filer HTTP/1.1"
... 192.168.0.61:33722 [11/Mar/2021:15:03:58.295] tridentnashttp~ ontapnashttp/ontapnashttp 2/0/1/397/400 200 403 - - ---- 2/2/0/1/0 0/0 "POST /servlets/netapp.servlets.admin.XMLrequest_filer HTTP/1.1"
... 192.168.0.61:33728 [11/Mar/2021:15:03:58.697] tridentnashttp~ ontapnashttp/ontapnashttp 1/0/2/74/77 200 816 - - ---- 3/3/0/1/0 0/0 "POST /servlets/netapp.servlets.admin.XMLrequest_filer HTTP/1.1"
... 192.168.0.61:33732 [11/Mar/2021:15:03:58.776] tridentnashttp~ ontapnashttp/ontapnashttp 1/0/2/357/360 200 403 - - ---- 4/4/0/1/0 0/0 "POST /servlets/netapp.servlets.admin.XMLrequest_filer HTTP/1.1"
... 192.168.0.61:33734 [11/Mar/2021:15:03:59.136] tridentnashttp~ ontapnashttp/ontapnashttp 2/0/1/53/57 200 9032 - - ---- 5/5/0/1/0 0/0 "POST /servlets/netapp.servlets.admin.XMLrequest_filer HTTP/1.1"
```

Creating a volume led to 5 successive Trident REST API calls of type POST, which were all successful (HTTP Code 200).  
You can also notice that requests all came from the host 192.168.0.61 (rhel1) which is were the Trident Replicaset is running (trident-csi-d47f5f5c6-phg9r):  

```bash
$ kubectl get pod -n trident -o wide
NAME                                READY   STATUS    RESTARTS   AGE    IP              NODE    NOMINATED NODE   READINESS GATES
trident-csi-5fmjq                   2/2     Running   0          3d1h   192.168.0.62    rhel2   <none>           <none>
trident-csi-d47f5f5c6-phg9r         6/6     Running   0          3d1h   192.168.24.37   rhel1   <none>           <none>
trident-csi-dv5h6                   2/2     Running   0          3d1h   192.168.0.63    rhel3   <none>           <none>
trident-csi-rcwg9                   2/2     Running   0          3d1h   192.168.0.61    rhel1   <none>           <none>
trident-operator-5c8bbf6754-bn2c2   1/1     Running   0          3d1h   192.168.24.36   rhel1   <none>           <none>
```

Time to clean up & move on !

```bash
kubectl delete -f pod-with-pvc-proxy.yaml
persistentvolumeclaim "pvc-proxy" deleted
pod "centos-proxy" deleted
```
