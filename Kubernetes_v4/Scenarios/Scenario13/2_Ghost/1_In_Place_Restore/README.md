#########################################################################################
# SCENARIO 13.1: In-place PVC restore
#########################################################################################

"Oh zut! I deleted some very ticket from my blog website !!!"  
"No worries, you can reuse the CSI Snapshot you created earlier without contacting the Infra teams"

<p align="center"><img src="Images/scenario13_1.jpg"></p>

To *restore* data, you can edit the object that defines that Application (in our case, a *deployment*) or patch it:

```bash
$ kubectl patch -n ghost deploy blog -p '{"spec":{"template":{"spec":{"volumes":[{"name":"content","persistentVolumeClaim":{"claimName":"mydata-from-snap"}}]}}}}'
deployment.apps/blog patched
```

That will trigger a new POD creation with the updated configuration:

```bash
$ kubectl get -n ghost pod
NAME                    READY   STATUS        RESTARTS   AGE
blog-6cbd945df-p8r8t    1/1     Terminating   0          5m22s
blog-57cdf6865f-ww2db   1/1     Running       0          6s
```

Time to refresh you blog website... Check this out, your latest ticket is back online !!  
Tadaaa, you have restored your data!  

Keep in mind that some applications may need some extra care once the data is restored (databases for instance).  

## Optional Cleanup (only to run if you are done with *snapshots* & *clones*)

```bash
$ kubectl delete ns ghost
namespace "ghost" deleted
```

## What's next

You can now move on to:

- [Scenario13_2](../2_Clone_for_new_app): Use snapshots for in place restore  
- [Scenario13_3](../3_what_happens_when): Don't be afraid  

Or go back to:

- the [Scenario13 FrontPage](../../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)