#########################################################################################
# SCENARIO 14.2: Test a new App with the same data
#########################################################################################

We will here fire up a new Ghost environment with a new version while keeping the same content. This would a good way to test a new release, while not copying all the data for this specific environment. In other words, you would save time by doing so.  

![Scenario14_2](Images/scenario14_2.jpg "Scenario14_2")

The first deployment uses Ghost v2.6. Let's try with Ghost 3.13 ...
```
# kubectl create -n ghost -f Ghost_clone/2_deploy.yaml
deployment.apps/blogclone created

# kubectl create -n ghost -f Ghost_clone/3_service.yaml
service/blogclone created

# kubectl get all -n ghost -l scenario=clone
NAME                TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/blogclone   NodePort   10.106.214.203   <none>        80:30081/TCP   12s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blogclone   1/1     1            1           28s
```
Let's check the result:  
=> http://192.168.0.63:30081

You can probably notice some differences between both pages...  

Using this type of mechanism in a CI/CD pipeline can definitely save time (that's for Devs) & storage (that's for Ops)!


## Optional Cleanup (only to run if you are done with *snapshots* & *clones*)

```
# kubectl delete ns ghost
namespace "ghost" deleted
```

## What's next

You can now move on to:    
- [Scenario14_1](../1_In_Place_Restore): Use snapshots for in place restore  
- [Scenario14_3](../3_what_happens_when): Don't be afraid  
- [Scenario15](../../Scenario15): Dynamic export policy management  

Or go back to:
- the [Scenario14 FrontPage](../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)