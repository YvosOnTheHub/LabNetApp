#########################################################################################
# Addenda 11: Install ArgoCD
#########################################################################################  

ArgoCD is a very popular tool for Kubernetes that enables Continuous Delivery of applications.  
We will deploy a minimal installation of ArgoCD via its Helm chart:  
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --version 6.7.3 -n argocd --create-namespace -f argocd_values.yaml
```
After a few seconds, you should see the following:
```bash
$ kubectl get -n argocd pod
NAME                                                   READY   STATUS    RESTARTS   AGE
pod/argocd-application-controller-0                    1/1     Running   0          11m
pod/argocd-redis-5459c8bf77-rhd9r                      1/1     Running   0          11m
pod/argocd-repo-server-6575c9c546-j7gcm                1/1     Running   0          11m
pod/argocd-server-6b86db9cc9-lw69j                     1/1     Running   0          11m

$ kubectl get -n argocd svc argocd-server 
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
argocd-server   LoadBalancer   172.26.127.119   192.168.0.212   80:31128/TCP,443:30883/TCP   11m
```
In this example, the Load Balancer provided the address 192.168.0.212 to ArgoCD.  
You can use that address in the browser to reach this application.  
Note that you don't need to log in the GUI as authentication was disabled.  

We also need to install the ArgoCD binary, which can be useful, especially if you need to register a second cluster in the environment:
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm -f argocd-linux-amd64
```
To interact with the binary, you need to find out the password for the admin user.  
You can use the following command to retrieve the inital value:  
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

There you go, ArgoCD is now ready to use!