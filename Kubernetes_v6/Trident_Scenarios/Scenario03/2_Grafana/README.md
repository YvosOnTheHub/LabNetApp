#########################################################################################
# SCENARIO 3: Navigate through Grafana
#########################################################################################

**GOAL:**  
Now that we have checked that Prometheus is working, we can connect to Grafana.

## A. Log in Grafana

The _monitoring_ namespaces has plenty of different services. Let's see how to access the Grafana dashboard:  
```bash
$ kubectl get -n monitoring svc -l app.kubernetes.io/name=grafana
NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
prometheus-grafana   LoadBalancer   10.102.68.158   192.168.0.211   80:30937/TCP   47d
```

This service is exposed via a LoadBalancer. You can either use that IP address provided by MetalLB, or go directly to http://grafana.demo.netapp.com.
The first time you enter Grafana, you are requested to login with a username & a password ...  
But how to find out what they are ??  

Let's look at the pod definition, maybe there is a hint there...  

```bash
$ kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana
NAME                                  READY   STATUS    RESTARTS   AGE
prometheus-grafana-6dc8c4bc89-bcjfs   3/3     Running   12         47d

$ kubectl describe $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o name) -n monitoring | grep GF_SECURITY
      GF_SECURITY_ADMIN_USER:      <set to the key 'admin-user' in secret 'prometheus-grafana'>      Optional: false
      GF_SECURITY_ADMIN_PASSWORD:  <set to the key 'admin-password' in secret 'prometheus-grafana'>  Optional: false
```

Let's check what secrets there are in this cluster  
```bash
$ kubectl get secrets -n monitoring -l app.kubernetes.io/name=grafana
NAME                 TYPE     DATA   AGE
prometheus-grafana   Opaque   3      47d

$ kubectl describe secrets -n monitoring prometheus-grafana | grep Data -A 4
Data
====
admin-password:  13 bytes
admin-user:      5 bytes
ldap-toml:       0 bytes
```

OK, so the data is there, and is encrypted... However, the admin can retrieve this information  
```bash
$ kubectl get secret -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].data.admin-user}"  | base64 --decode ; echo
admin

$ kubectl get secret -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].data.admin-password}"  | base64 --decode ; echo
prom-operator
```

By the way, if you have installed _krew_ & the _view-secret_ plugin (cf[Addenda06](../../../Addendum/Addenda06/)), you could get those secrets decoded in a much simpler way:  
```bash
$ kubectl view-secret -n monitoring prometheus-grafana admin-user; echo
admin

$ kubectl view-secret -n monitoring prometheus-grafana admin-password; echo
prom-operator
```

There you go!
You can now properly login to Grafana.

## B. Create your own graph

Click on the Dashboard meny on the left, then on the "New" button on the right side of the screen.  
From here you have various choices, such as create your own dashboard, or import one.  

You can here configure a new graph by adding metrics. By typing 'trident' in the 'Metrics' box, you will see all metrics available.

## C. Import a graph

There are several ways to bring dashboards into Grafana.  

*Manual Import*  
Click on the Dashboard meny on the left side of the screen, then 'New' & 'Import'.  
Copy & paste the content of a JSON file, in order to start using this new dashboard.  
The _issue_ with this method is that if the Grafana POD restarts, the dashboard will be lost...  

*Persistent Dashboard*  
The idea here would be to create a ConfigMap pointing to the Trident dashboard json file.

```bash
$ kubectl create configmap -n monitoring cm-trident-dashboard-dir --from-file=Dashboards/
configmap/cm-trident-dashboard-dir created

$ kubectl label configmap -n monitoring cm-trident-dashboard-dir grafana_dashboard=1
configmap/cm-trident-dashboard-dir labeled
```

The dashboards present in the Dashboards folder will automatically appear in the Grafana list. 
Now, where can you find this dashboard:  
- Click on the 'Dashboard' icon on the left side bar (it looks like 4 small squares)  
- You can either research 'Trident' or find the link be at the bottom of the page  

<p align="center"><img src="../Images/trident_dashboard_20_07.jpg"></p>

Your turn to have fun!  

## D. What's next


OK, you have everything to monitor Trident, let's continue with other scenarios :
- Add ONTAP data in Prometheus with [Harvest](../3_Harvest)  
- [Scenario05](../../Scenario05): Configure your first iSCSI backends & storage classes  
- [Scenario10](../../Scenario10): Using Virtual Storage Pools  
- [Scenario13](../../Scenario13): Dynamic export policy management  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)