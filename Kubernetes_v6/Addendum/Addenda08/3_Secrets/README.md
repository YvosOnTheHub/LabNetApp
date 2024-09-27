#########################################################################################
# ADDENDA 8: Use a Docker login with secrets !
#########################################################################################

The alternative to manually pull images on each node consists in managing the Docker credentials via Kubernetes secrets.
https://kubernetes.io/docs/concepts/configuration/secret/#using-imagepullsecrets
https://kubernetes.io/docs/concepts/configuration/secret/#restrictions

In order to use this methodology, several steps must be performed:

## A. Docker credentials

On the master node (_rhel3_ on the Lab On Demand), log into docker with the user you have created.  
```bash
$ podman login -u my_user -p my_password
Login Succeeded!
```

Note that the file where the registry users & passwords are stored locally depends on the tool you use:  
- docker: /root/.docker/config.json
- podman: $XDG_RUNTIME_DIR/containers/auth.json (in the lab on RHEL3, this is /run/user/0/containers/auth.json)

As we use _podman_ in this lab, let's look into the corresponding file:
```bash
$ more /run/user/0/containers/auth.json
{
        "auths": {
                "docker.io": {
                        "auth": "dHN1cGQw............="
                },
                "registry.demo.netapp.com": {
                        "auth": "cmVnaXN0cnl1c2VyOk5ldGFwcDEh"
                }
        }
}
```

You can use the _base64_ binary to decode this hash & retrieve your credentials:  
```bash
$ echo "dHN1cGQw...........=" | base64 --decode
my_user:my_password
$ echo "cmVnaXN0cnl1c2VyOk5ldGFwcDEh" | base64 --decode
registryuser:Netapp1!
```

In a production environment, you would probably want to use a credentials store for this purpose.

## B. Create a Kubernetes secret

Next, you need to create a Kubernetes object that will be used by your applications to pull images from the Docker Hub.  
Since we have already used the command _docker login_, the secret will be of type _generic_ & will point to json file created earlier.  
```bash
$ kubectl create secret docker-registry dockerhubcredentials \
   --docker-server=docker.io \
   --docker-username=my_user \
   --docker-password=my_password
secret/dockerhubcredentials created
```

:boom:  
**Be aware that secrets are namespaces bound, ie not cluster wide.  
If you planning on using different namespaces, you will need to create this secret in every one of them.**  
:boom:  

## C. Use this secret with your applications

Now that I have a _secret_ (https://www.youtube.com/watch?v=WKr2e0VfLdU), you just need to use the parameter _imagePullSecrets_ in your application specs

Compare:

```bash
spec:
  containers:
    - name: centos
      image: centos:centos7
      command:
        - /bin/sh
        - "-c"
        - "sleep 60m"
```

With:

```bash
spec:
  containers:
    - name: centos
      image: centos:centos7
      command:
        - /bin/sh
        - "-c"
        - "sleep 60m"
  imagePullSecrets:
    - name: dockerhubcredentials
```

That way, the first time this application will be launched, Kubernetes will provide the right credentials to pull the container image.  

## D. Linking the secret to the application service account

While using the _imagePullSecrets_ parameter in pods is easy, it could easily become cumbersome, especially if you have many pods in your namespace, simply because each pod must have that value set. That said Helm can do it for you when using that tool.   

A good alternative would be to work at the **Service Account** level.  
According to the Kubernetes documentation: "A service account provides an identity for processes that run in a Pod".  
Why not adding a secret to that identity?  

Often, a service account is used by several pods, and you will always see at least a _default_ service account in each namespace.  
Just note that working at the SA level must also be done in each namespace that requires access to the Docker Hub.  
Last, make you link the secret to the correct service accounts used by the application:  
```bash
$ kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "dockerhubcredentials"}]}'
serviceaccount/default patched
```
& voilà !
