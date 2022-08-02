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
$ docker login -u my_user -p my_password
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

If you take a look at the config.json file that just got created, you will find a hash for your credentials

```bash
$ more /root/.docker/config.json
{
        "auths": {
                "https://index.docker.io/v1/": {
                        "auth": "dHN1cGQw...........="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/18.09.1 (linux)"
        }
}
```

You can use the _base64_ binary to decode this hash & retrieve your credentials:

```bash
$ echo "dHN1cGQw...........=" | base64 --decode
my_user:my_password
```

In a production environment, you would probably want to use a credentials store for this purpose.

## B. Create a Kubernetes secret

Next, you need to create a Kubernetes object that will be used by your applications to pull images from the Docker Hub.  
Since we have already used the command _docker login_, the secret will be of type _generic_ & will point to json file created earlier.

```bash
$ kubectl create secret generic dockerhubcredentials --from-file=.dockerconfigjson=/root/.docker/config.json --type=kubernetes.io/dockerconfigjson
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
