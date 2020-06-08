#########################################################################################
# SCENARIO 3: Configure Grafana & make your first graph
#########################################################################################

**GOAL:**  
Prometheus does not allow you to create a graph with different metrics, you need to use Grafana for that.  
Installing Prometheus with Helm also comes with this tool.  
We will learn how to access Grafana, and configure a graph.


## A. Expose Grafana

With Grafana, we are facing the same issue than with Prometheus with regards to accessing it.
We will then modify its service in order to access it from anywhere in the lab, with a *NodePort* configuration
```
# kubectl edit -n monitoring svc prom-operator-grafana
```

### BEFORE:
```
spec:
  clusterIP: 10.97.208.231
  ports:
  - name: service
    port: 80
    protocol: TCP
    targetPort: 3000
  selector:
    app.kubernetes.io/instance: prom-operator
    app.kubernetes.io/name: grafana
  sessionAffinity: None
  type: ClusterIP


```

### AFTER: (look at the ***nodePort*** & ***type*** lines)
```
spec:
  clusterIP: 10.97.208.231
  ports:
  - name: service
    nodePort: 30001
    port: 80
    protocol: TCP
    targetPort: 3000
  selector:
    app.kubernetes.io/instance: prom-operator
    app.kubernetes.io/name: grafana
  sessionAffinity: None
  type: NodePort
```

You can now access the Grafana GUI from the browser using the port 30001 on RHEL3 address (http://192.168.0.63:30001)


## B. Log in Grafana

The first time to enter Grafana, you are requested to login with a username & a password ...
But how to find out what they are ??

Let's look at the pod definition, maybe there is a hint there...

```
# kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana
NAME                                     READY   STATUS    RESTARTS   AGE
prom-operator-grafana-7d99d7985c-98qcr   3/3     Running   0          2d23h

# kubectl describe pod prom-operator-grafana-7d99d7985c-98qcr -n monitoring
...
    Environment:
      GF_SECURITY_ADMIN_USER:      <set to the key 'admin-user' in secret 'prom-operator-grafana'>      Optional: false
      GF_SECURITY_ADMIN_PASSWORD:  <set to the key 'admin-password' in secret 'prom-operator-grafana'>  Optional: false
...
```
Let's check what secrets there are in this cluster
```
# kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana
NAME                    TYPE     DATA   AGE
prom-operator-grafana   Opaque   3      2d23h


# kubectl describe secrets -n monitoring prom-operator-grafana
Name:         prom-operator-grafana
...
Data
====
admin-password:  13 bytes
admin-user:      5 bytes
...
```
OK, so the data is there, and is encrypted... However, the admin can retrieve this information
```
# kubectl get secret -n monitoring prom-operator-grafana -o jsonpath="{.data.admin-user}" | base64 --decode ; echo
admin

# kubectl get secret -n monitoring prom-operator-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
prom-operator
```

There you go!
You can now properly login to Grafana.


## E. Configure Grafana

The first step is to tell Grafana where to get data (ie Data Sources).
In our case, the data source is Prometheus. In its configuration, you then need to put Prometheus's URL (http://192.168.0.63:30000)
You can also specify in this lab that Prometheus will be the default source.
Click on 'Save & Test'.


## F. Create your own graph

Hover on the '+' on left side of the screen, then 'New Dashboard', 'New Panel' & 'Add Query'.
You can here configure a new graph by adding metrics. By typing 'trident' in the 'Metrics' box, you will see all metrics available.


## G. Import a graph

There are several ways to bring dashboards into Grafana.  

*Manual Import*  
Hover on the '+' on left side of the screen, then 'New Dashboard' & 'Import'.
Copy & paste the content of the _Trident_Dashboard_Std.json_ file in this directory.  
The _issue_ with this method is that if the Grafana POD restarts, the dashboard will be lost...  

*Persistent Dashboard*  
The idea here would be to create a ConfigMap pointing to the Trident dashboard json file:  
```
# kubectl create configmap -n monitoring tridentdashboard --from-file=Trident_Dashboard_Std.json
configmap/tridentdashboard created

# kubectl label configmap -n monitoring tridentdashboard grafana_dashboard=1
configmap/tridentdashboard labeled
```
When Grafana starts, it will automatically load every configmap that has the label _grafana_dashboard_.  
In the Grafana UI, you will find the dashboard in its own _Trident_ folder.  

Now, where can you find this dashboard:  
- Hover on the 'Dashboard' icon on the left side bar (it looks like 4 small squares)  
- Click on the 'Manage' button  
- You then access a list of dashboards. You can either research 'Trident' or find the link be at the bottom of the page  

![Trident Dashboard](Images/trident_dashboard.jpg "Trident Dashboard")



