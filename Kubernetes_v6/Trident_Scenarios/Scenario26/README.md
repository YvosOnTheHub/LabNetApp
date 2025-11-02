#########################################################################################
# SCENARIO 26: Multi tasking !
#########################################################################################

Trident 25.06 introduces concurrent operations for block protocols (iSCSI and FCP), which greatly improves performance, not in IOPS, but rather in applications readiness, especially for large environments.  

Not all operations can run in parallel, but there are plenty of tasks that Trident can run concurrently.  

The following page explains very well the why and the how: https://community.netapp.com/t5/Tech-ONTAP-Blogs/Trident-Controller-Parallelism/ba-p/461918.  
It all also contains metrics observed during benchmarks with hundreds of PVC.  

In the context of this lab, we will see how to enable that feature and also run some tests.  
We will first run some baseline tests without the feature, and compare them with 2 more tests once the concurrency is enabled.  

**TL;DR: BEGINNING**  
**This table summarized my findings:**

| Configuration | Feature enabled | Total time all PVC bound | Average per PVC |
| :--- | :---: | :---: | :---: |
| [100 POD with 2 PVC](#config1) | no | 384 sec | 1,92 sec | 
| [100 POD with 2 PVC](#config2) | yes | 240 sec | 1,2 sec | 
| [200 POD with 2 PVC](#config3) | no | 769 sec | 1,92 sec | 
| [200 POD with 2 PVC](#config4) | yes | 391 sec | 0,98 sec | 

In summary, in the specific context of this lab environment, enabling Trident's concurrency feature reduces by a ratio between 40% and 50% the readiness time for the persistent volumes (ie the time it takes for the PVC to reach _Bound_ state).
Using REST API may even provide better results! However, this will need a more recent version of ONTAP.  

**TL;DR: END**

## A. Preparation

Make sure you run **Trident 25.06** minimum , otherwise comparing results will make less sense.  

This feature is currently only available for **iSCSI** and **FCP** protocols with the **ONTAP-SAN** driver. Trident will not allow its activation if it detects existing backends with other protocols or drivers.  
Let's delete existing backends, except for the iSCSI ONTAP-SAN one.  

The 2 following commands will filter all the existing backends and remove what is not compatible for this lab:  
```bash
$ kubectl get tbc -n trident -o json | \
  jq -r '.items[] | select(.spec.storageDriverName | test("nas|economy")) | .metadata.name' | \
  xargs -r kubectl delete tbc -n trident
tridentbackendconfig.trident.netapp.io "backend-tbc-nfs" deleted
tridentbackendconfig.trident.netapp.io "backend-tbc-nfs-qtrees" deleted
tridentbackendconfig.trident.netapp.io "backend-tbc-smb" deleted
tridentbackendconfig.trident.netapp.io "backend-tbc-iscsi-eco" deleted

$ kubectl get tbc -n trident -o json | \
  jq -r '.items[] | select(.spec.sanType=="nvme") | .metadata.name' | \
  xargs -r kubectl delete tbc -n trident
tridentbackendconfig.trident.netapp.io "backend-tbc-nvme" deleted
```

<u>NB</u>:
Those backends can only be deleted once all their corresponding PVC are also erased.  
If you have tested other scenarios, you may want to do some clean up first.  

All the tests are going to be done in a specific namespace, let's start by creating this one:  
```bash
$ kubectl create ns sc26concurrency
namespace/sc26concurrency created
```

Last, if you have not yet read the [Addenda08](../../Addendum/Addenda08/) about the Docker Hub management, it would be a good time to do so.  
Also, if no action has been made with regards to the container images, you can find a shell script in this directory *scenario26_pull_images.sh* to pull images utilized in this scenario if needed andl push them to the local private registry:  
```bash
sh scenario26_pull_images.sh
```

<a name="config1"></a>

## B. Baseline1: 100 POD with 2 PVC

This folder contains a file called *app_template.yaml*, which aims at creating a Busybox app (*busybox-##*) with 2 iSCSI RWO PVC (*pvc-##1* and *pvc-##2*). 
We will use a loop to create 100 instances of that application, each _##_ field used to create a specific iteration.  

This loop also displays the time at multiple stages:
- script startup
- once all the PVC are in a _Bound_ state
- once all the PVC are mounted in their respective pods

The loop takes a few minutes to complete and the outputs will be saved in a local text file:  
```bash
(date; c=1; max=100; for i in {a..z}; do for j in {a..z}; do (( c > max )) && break 2; sed "s/##/$i$j/g" app_template.yaml | kubectl apply --wait=false -f -; ((c++)); done; done; \
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc --all --timeout 5h -n sc26concurrency; date; \
kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --timeout 5h -n sc26concurrency; date) > sc26_baseline1.txt
```
In my case, here are the results I got: 
- 09:51:31 - script startup 
- 09:57:55 - all PVC in _Bound_ state
- 09:58:16 - all PODs running

Let's clean up the namespace to free up resources. We will just delete the namespace for this:  
```bash
(kubectl delete ns sc26concurrency; 
frames="/ | \\ -"
until [ $(kubectl get pv | grep sc26concurrency | wc -l) -eq 0 ]; do
    for frame in $frames; do sleep 0.5; printf "\rwaiting for all PV to be deleted $frame"; done
done)
```
It takes about a minute to complete, until all PV are really deleted. Once done, you can proceed.  

<a name="config2"></a>

## C. Baseline2: 200 POD with 2 PVC

Let's reuse the same script, but for 200 PODs this time:  
```bash
kubectl create ns sc26concurrency

(date; c=1; max=200; for i in {a..z}; do for j in {a..z}; do (( c > max )) && break 2; sed "s/##/$i$j/g" app_template.yaml | kubectl apply --wait=false -f -; ((c++)); done; done; \
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc --all --timeout 5h -n sc26concurrency; date; \
kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --timeout 5h -n sc26concurrency; date) > sc26_baseline2.txt
```
In this second test, here are the results I got: 
- 01:16:52 - script startup
- 01:29:41 - all PVC in _Bound_ state
- 01:30:19 - all PODs running

## D. Concurrency enablement

This preview feature can be enabled with a specific flag in the Helm chart:  
```bash
helm upgrade trident netapp-trident/trident-operator --version 100.2510.0 -n trident --reuse-values --set enableConcurrency=true
```
This will trigger a reconfiguration of the Trident controller, which leads to a pod restart.  
To verify that this parameter was applied, you can run the following:  
```bash
$ kubectl get -n trident po -l app=controller.csi.trident.netapp.io -o yaml | grep concur
      - --enable_concurrency=true
```

<a name="config3"></a>

## E. Benchmark1: 100 POD with 2 PVC

Now that the feature is enabled, you can run a benchmark after recreating the namespace:  
```bash
kubectl create ns sc26concurrency

(date; c=1; max=100; for i in {a..z}; do for j in {a..z}; do (( c > max )) && break 2; sed "s/##/$i$j/g" app_template.yaml | kubectl apply --wait=false -f -; ((c++)); done; done; \
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc --all --timeout 5h -n sc26concurrency; date; \
kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --timeout 5h -n sc26concurrency; date) > sc26_benchmark1.txt
```
In this test, here are the results I got: 
- 12:42:33 - script startup
- 12:46:33 - all PVC in _Bound_ state
- 12:47:17 - all PODs running

Now that this test is finished, you can clean up the namespace:  
Let's clean up the namespace to free up resources. We will just delete the namespace for this:  
```bash
(kubectl delete ns sc26concurrency; 
frames="/ | \\ -"
until [ $(kubectl get pv | grep sc26concurrency | wc -l) -eq 0 ]; do
    for frame in $frames; do sleep 0.5; printf "\rwaiting for all PV to be deleted $frame"; done
done)
```

<a name="config4"></a>

## F. Benchmark2: 200 POD with 2 PVC

Let's reuse the same script, but for 200 PODs this time:  
```bash
kubectl create ns sc26concurrency

(date; c=1; max=200; for i in {a..z}; do for j in {a..z}; do (( c > max )) && break 2; sed "s/##/$i$j/g" app_template.yaml | kubectl apply --wait=false -f -; ((c++)); done; done; \
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc --all --timeout 5h -n sc26concurrency; date; \
kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --timeout 5h -n sc26concurrency; date) > sc26_benchmark2.txt
```
In this second test, here are the results I got: 
- 12:55:05 - script startup
- 01:01:36 - all PVC in _Bound_ state
- 01:04:21 - all PODs running          

One last clean up:  
```bash
(kubectl delete ns sc26concurrency; 
frames="/ | \\ -"
until [ $(kubectl get pv | grep sc26concurrency | wc -l) -eq 0 ]; do
    for frame in $frames; do sleep 0.5; printf "\rwaiting for all PV to be deleted $frame"; done
done)
```

## G. Disable the concurrency feature

This can simply be done following the same method used earlier:  
```bash
helm upgrade trident netapp-trident/trident-operator --version 100.2510.0 -n trident --reuse-values --set enableConcurrency=false
```
To verify that this change was applied, you can run the following:  
```bash
$ kubectl get -n trident po -l app=controller.csi.trident.netapp.io -o yaml | grep concur
      - --enable_concurrency=false
```