#########################################################################################
# ADDENDA 13: Install ArgoCD in this lab
#########################################################################################

ArgoCD is a Continuous Delivery tool that is becoming more & more popular.  
In a nutshell, you can use it in a GitOps fashion. It will monitor your code repository & apply changes to the infrastructure when a new commit/push has been performed.  

Trident 21.04 introduced backend management through yaml files & Kubernetes CRD.  
Its lifecycle can then be totally integrated into ArgoCD.

I will describe here how to install ArgoCD (super easy) & how to access it.  
I consider that a Load Balancer, such as MetalLB, will assign an IP address to the ArgoCD service upon creation.  
Refer to [Addenda05](../Addenda05) to intall MetalLB.  

The first part described how to install ArgoCD in its own namespace, as well as updating its service.

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.0.2/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Now, let's retrive its IP address, automatically assigned by MetalLB

```bash
kubectl get svc -n argocd argocd-server | awk '{ print $4 }'
EXTERNAL-IP
192.168.0.140
```

Last, you need to retrieve the password for the admin account.  
The initial password is auto-generated and stored as clear text in the field password in a secret named argocd-initial-admin-secret

```bash
$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
nnrSlpSsgWSQscJn
```

& voilà, ArgoCD is installed & ready to be used !

<p align="center"><img src="Images/ArgoCD_UI.jpg"></p>