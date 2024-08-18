#########################################################################################
# ADDENDA 5: Install the Kubernetes dashboard
#########################################################################################

By default, Kubernetes does not come with a dashboard. However, if you want to use one, here is a method to install it & access it.  
In the following procedure, we will:
- Install the official Kubernetes dashboard via its Helm chart  
- Create a _service account_  
- Retrieve the port to use to connect to the dashboard  
- Retrieve the token that can be accessed to log into the UI  

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace -n kubernetes-dashboard -f dashboard_values.yaml
```
The official Kubernetes dashboard uses now Kong to manage API.  
Parameters were given to the helm chart so that a Proxy appears for Kong, which then allows you to connect to the dashboard from the Lab on Demand jumphost.  

You can easily retrieve the port used for this proxy (_30851_ in my example):  
```bash
$ kubectl get -n kubernetes-dashboard svc kubernetes-dashboard-kong-proxy
NAME                              TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
kubernetes-dashboard-kong-proxy   NodePort   10.109.86.10   <none>        443:30851/TCP   81m
```
There you go, you can now connect to the dashboard with _https://192.168.0.63:30851_.  

Last, need to create a service account, a user & a token secret, which will be asked when connecting to this service:  
```bash
$ kubectl create -f dashboard_user.yaml
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-user created
secret/admin-user created
```

Let's retrieve the token:  
```bash
$ kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d; echo
eyJhbGciOiJSUzI1NiIsImtpZCI6IlE2MWg1TDFHU0lNcWd3YzV6S3JpcWNmRTdZMTB2S21jTXduYWlQZnJXUGMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIxZDE2Njg5YS00MTc0LTRiNzUtOWQwZC1iN2NkMWVhMTBlYzIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6YWRtaW4tdXNlciJ9.DWR8WkRBelAL0rRfUDK5k-L_X4rMKa5YGR2AzF8ttwlC6MEFzhqIyLkRtQyf5RP1Tg16IaEJt5XuPpmMVCFPVXlAazPQoc0hGD-ftitgjFQJtUdnn3J4JoPpQYE4fZ1qMyR9IyqMkGvl8ndkjjmWHRc_djaOR9JW4zLe_IF06mCNeKam9AF85DbXt7L7DQGfHrTn0j715Skky0cdemFaPe75g51RFBdNRyDD9-Vt0PlxsAgfXjKn_syEsllh_6ri58p9HuiRHTbUsc0HoMe9zZNU_ngm6otygbNYznrAlTD-TqdP7Y9KM2iEW-egVQ5x-7P2-wZA9xxjqr7b-55YSw
```

& voilà, you have all you need to use the dashboard now!  

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?