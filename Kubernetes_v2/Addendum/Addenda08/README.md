#########################################################################################
# ADDENDA 8: Install the Kubernetes dashboard
#########################################################################################

By default, Kubernetes does not come with a dashboard. However, if you want to use one, here is a method to install it & access it.  
In the following procedure, we will:

- Install the official Kubernetes dashboard
- Create a _service account_ & a _cluster role binding_
- Change the service to a LoadBalancer type
- Retrieve the token that can be accessed to log into the UI

```bash
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml
namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created

$ kubectl create -f dashboard-service-account.yaml
serviceaccount/admin-user created

$ kubectl create -f dashboard-clusterrolebinding.yaml
clusterrolebinding.rbac.authorization.k8s.io/admin-user created

$ kubectl -n kubernetes-dashboard patch service/kubernetes-dashboard -p '{"spec":{"type":"LoadBalancer"}}'
service/kubernetes-dashboard patched
```

The dashboard is now installed. Let's look at how to to access it.

```bash
$ kubectl get svc -n kubernetes-dashboard
NAME                        TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP      10.111.77.217   <none>          8000/TCP        30s
kubernetes-dashboard        LoadBalancer   10.111.247.19   192.168.0.142   443:32603/TCP   30s
```

Notice that the port is **443**, you will then use HTTPS to reach this service IP address (& also, accept the usual unsecure site warnings)

The _secret_ created for the service account contains the token that you can copy & paste into the UI.

```bash
$ kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
Name:         admin-user-token-bn2v7
Namespace:    kubernetes-dashboard
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: admin-user
              kubernetes.io/service-account.uid: 50d3a202-603f-4a5e-a3a7-06bb13eb8c02

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  20 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6Img2c2RKNlRMa1JPdi1Rd2t3anVOeVVJUVRkX21tMUFocWZ3Y0NIUW1rS3cifQeyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLWJuMnY3Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI1MGQzYTIwMi02MDNmLTRhNWUtYTNhNy0wNmJiMTNlYjhjMDIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZXJuZXRlcy1kYXNoYm9hcmQ6YWRtaW4tdXNlciJ9FsXIQP0jMrS-J2oRCfSosKIr_xf5kF7cEu3wNw0A-9nQlgF3cb1sOW2cYmtcmvmRqs5rKTd8T-vrmz6GWh_-HfYsUpW7dTqQuB0lxb-kQhepwEH-TY5cKdSnVR9mZN6kfcCm06w8_3oJLC0Apf6k2f4RiOL34b_hv5l7USEnrjktBf47d00ZuTISSj1x0kdEaCn0uUdfFVgGh5pcD_KDPcGSm8pCdgmLjoZ_9CzJqtSIfSBbhVQGS_lyo-ltp9wqwqv3oniFKbSJK06Aj9OJXKaoWXdQi0Ebm7_7joFheyyoSJvWKx7owcEzQqj1rPA8fm2ZFJGdhlQYok3fE8rndA
```

## What's next

Back to the [frontpage](https://github.com/YvosOnTheHub/LabNetApp)?