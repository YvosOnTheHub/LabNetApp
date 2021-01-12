#########################################################################################
# ADDENDA 9: How many pull requests can I do ?
#########################################################################################

This page follows the steps provided on https://docs.docker.com/docker-hub/download-rate-limit/.  

The method used requires the tool called _jq_. To check if it is alrady present, you can use either of the following:
(this tool is not installed in the Lab on Demand)

```bash
$ jq
OR
$ yum list installed | grep jq
```

In order to deploy jq, please use the following command:

```bash
yum install jq -y
```

Next, Let's check how many _pull_ requests we have left, as an anonymous user.  
This requires the creation of a environment variable called _TOKEN_ that contains a authentication token from the Docker Hub.  
We then use this token to request data from the Hub.  

```bash
$ TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
$ curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep RateLimit
RateLimit-Limit: 100;w=21600
RateLimit-Remaining: 0;w=21600
```

You most probably will get the same result, ie no _pull request_ left...

Let's do the same, but this time with your own user. You just need to replace the two parameters _username_ & _password_ in the following

```bash
$ TOKEN=$(curl --user 'username:password' "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
$ curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep RateLimit
RateLimit-Limit: 200;w=21600
RateLimit-Remaining: 197;w=21600
```

This time, you will see that you have plenty of _pull requests_ left to use.  
However, if you need more, you will either have to wait for 6 hours, or use a subscription plan.
