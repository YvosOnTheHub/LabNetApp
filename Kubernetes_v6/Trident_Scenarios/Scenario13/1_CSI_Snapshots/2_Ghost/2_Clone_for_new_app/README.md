#########################################################################################
# SCENARIO 13.2: Test a new App with the same data
#########################################################################################

We will here fire up a new Ghost environment with a new version while keeping the same content. This would a good way to test a new release, while not copying all the data for this specific environment. In other words, you would save time by doing so.  

<p align="center"><img src="Images/scenario13_2.jpg"></p>

The first deployment uses Ghost v2.6. Let's try with Ghost 3.13 ...  
```bash
$ kubectl create -f Ghost_clone/2_deploy.yaml
deployment.apps/blogclone created

$ kubectl create -f Ghost_clone/3_service.yaml
service/blogclone created

$ kubectl get all -n ghost -l app=blogclone
NAME                             READY   STATUS    RESTARTS   AGE
pod/blogclone-7b77577986-dqwtw   1/1     Running   0          55s

NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/blogclone   NodePort   10.110.156.53   <none>        80:30081/TCP   46s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/blogclone   1/1     1            1           55s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/blogclone-7b77577986   1         1         1       55s
```

Let's check the result:  
=> `http://192.168.0.63:30081`

You can probably notice some differences between both pages...  

Using this type of mechanism in a CI/CD pipeline can definitely save time (that's for Devs) & storage (that's for Ops)!

## Optional Cleanup (only to run if you are done with *snapshots* & *clones*)

```bash
$ kubectl delete ns ghost
namespace "ghost" deleted
```

## What's next

You can now move on to:  
- [Scenario13_1](../1_In_Place_Restore): Use snapshots for in place restore  
- [Scenario13_3](../3_what_happens_when): Don't be afraid  

Or go back to:

- the [Scenario13 FrontPage](../../../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)