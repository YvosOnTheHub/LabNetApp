#########################################################################################
# SCENARIO 18: Kubernetes, Trident & GitOps
#########################################################################################

Trident 21.04 introduces the support of backend management through Yaml files & Kubernetes CRD.  
That opens the door to a better lifecycle management as you can now deploy the Trident Operator with Continuous Tools, like ArgoCD.

This scenario will guide you through the following:

- Push all the necessary Docker images to the lab registry
- Creation of a Git repository
- Host scenario files in this Git repository
- Integration & Deployment of Trident with ArgoCD
- Integration & Deployment of a small app with ArgoCD
- Update of the app code, push in the repository & automated update on Kubernetes

<p align="center"><img src="Images/scenario18_architecture.jpg"></p>

The prerequisites of this lab are the following:

- Completly uninstall Trident (there is a script called _trident_uninstall.sh_ in this folder that will do it for you)
- Install the Load Balancer [MetalLB](../../Addendum/Addenda05)
- Install the lightweight Git repository [Gitea](../../Addendum/Addenda12) (only the paragraph #A) & create an admin user (demo/netapp123)
- Install the continuous deployment tool [ArgoCD](../../Addendum/Addenda13)

## A. Docker images

The first part of this scenario is about managing Trident images. This will be done in 3 successive steps:  

- Pull Trident images from the Docker Hub
- Tag these images
- Push them to the local registry  

You will find in this folder a script called _push_scenario_images_to_private_repo.sh_ that will do the job for you.  
Refer to the chapter [Addenda08](../../Addendum/Addenda08) to learn more about Docker images management, as it may require you to use your own login.

## B. Gitea repository

Let's first create a new repository in Gitea:

```bash
curl -X POST "http://192.168.0.64:3000/api/v1/user/repos" -u demo:netapp123 -H "accept: application/json" -H "content-type: application/json" -d '{
  "name":"scenario18",
  "description": "argocd repo"
}'
```

Now, you can setup the local Git parameters that will be used later on:

```bash
git config --global user.email lod.demo.netapp.com
git config --global user.name "lod"
git config --global credential.helper store
git config --global alias.adcom '!git add -A && git commit -m'
git config --global push.default simple
```

You will find here a folder called _Repository_ that will be used as a base. Feel free to add your own apps in there for the sake of fun!  
The following will push the data to the newly created repository. Once pushed, you can connect to the Gitea UI & see the result.

```bash
cp -R ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18/Repository ~/
cd ~/Repository
git init
git add .
git commit -m "initial commit"
git remote add origin http://192.168.0.64:3000/demo/scenario18.git
git push -u origin master
```

& now the fun starts!

## C. Environment configuration

We are going to create 3 ArgoCD applications:

1. Trident installation (with the UI)
2. Trident configuration (with kubectl)
3. Ghost (with kubectl)

### 1. Trident Installation with the UI

Once logged into ArgoCD, click on the button "New App".  
Then fill up the form with the following parameters:

- Application Name: _trident-installation_
- Project: _default_
- Sync Policy: _Manual_
- Sync Options: Check _auto-create namespace_
- Repository URL: _http://192.168.0.64:3000/demo/scenario18_
- Revision: _master_
- Path: _Infrastructure/Trident-Installer_
- Cluster URL: _https://kubernetes.default.svc_
- Namespace: _trident_

Finally, click on the **create** button at the top of the form.  
The app has now been created, but remains in a _out-of-sync_ status, which means that ArgoCD did not run this application.  
This is totally normal as I explicitly chose a manual sync policy. Now, click on the **sync** button & watch the magic.  
You will also notice that the UI provides you with a graphical view of all the objects of this application.

Let's check that Trident has been indeed installed:

```bash
$ kubectl get tver -n trident
NAME      VERSION
trident   21.04.0
```

By the way, these ArgoCD apps are actually Kubernetes objects:

```bash
$ kubectl get app -n argocd trident-installation
NAME                   SYNC STATUS   HEALTH STATUS
trident-installation   Synced        Healthy
```

### 2. Trident Configuration with the command line

We have seen how to create & sync an application in ArgoCD's UI.  
Let's see how to create an app with the cli:

```bash
$ kubectl create -n argocd -f ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18/ArgoCD/argocd_trident_config.yaml
application.argoproj.io/trident-configuration created

$ kubectl get app -n argocd trident-configuration
NAME                    SYNC STATUS   HEALTH STATUS
trident-configuration   Synced        Healthy
```

Since I explicitly mentioned in the yaml file that the app has to auto-synchronize, ArgoCD has already created all the objects.

```bash
$ kubectl get tbc,secret -n trident
NAME                                                                BACKEND NAME   BACKEND UUID                           PHASE   STATUS
tridentbackendconfig.trident.netapp.io/backend-tbc-argocd-default   argocd-nas     05574e61-25d6-463a-b299-be070ac93262   Bound   Success

NAME                                   TYPE                                  DATA   AGE
secret/ontap-nfs-svm-secret-username   Opaque                                2      6h9m

$ kubectl get sc
NAME                                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
argocd-storage-class-nas (default)   csi.trident.netapp.io   Delete          Immediate           false                  6h10m
```

### 3. Ghost installation with the command line

We can reuse the same steps to create an applciation to run Ghost.  
I will not choose to configure the auto-sync option, so that we can witness the behavior later on.

```bash
$ kubectl create -n argocd -f ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18/ArgoCD/argocd_ghost.yaml
application.argoproj.io/ghost created

$ kubectl get app -n argocd ghost
NAME    SYNC STATUS   HEALTH STATUS
ghost   OutOfSync     Missing
```

Let's go back to the ArgoCD UI & click on the **Sync** button of the _ghost_ app.  
Leave all parameters as they appear, and click on _synchronize_.

```bash
kubectl get app -n argocd ghost
NAME    SYNC STATUS   HEALTH STATUS
ghost   Synced        Healthy

$ kubectl get -n ghost svc,pod,pvc
NAME           TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
service/blog   NodePort   10.110.3.94   <none>        80:30080/TCP   6h10m

NAME                      READY   STATUS    RESTARTS   AGE
pod/blog-96868887-tlthj   1/1     Running   0          6h10m

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS               AGE
persistentvolumeclaim/blog-content   Bound    pvc-1e319499-0021-41a5-ba85-a0b549310c13   10Gi       RWX            argocd-storage-class-nas   6h10m
```

## D. Code update

### 1. Infrastructure update: Kubernetes storage class modification

Let's introduce the possibility to expand PVC. For a very small environment, you could just update your storage class & you will be good to go.  
However, for large customers with different environments, you would have to repeat the same task on each cluster...  
With GitOps, you can simply update your code repository (& by code, one could understand golden configuration or template) & apply it on the whole infrastructure at once.

Expanding a volume is enabled with the option _allowVolumeExpansion_ (cf [scenario09](../Scenario09)), which is currently disabled.  

```bash
$ kubectl get sc
NAME                                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
argocd-storage-class-nas (default)   csi.trident.netapp.io   Delete          Immediate           false                  3h1m

$ echo "allowVolumeExpansion: true" >> ~/Repository/Infrastructure/Trident-Configuration/sc-csi-ontap-nas.yaml
```

Now that the code is updated locally, you can perform the commit & push steps in order to bring the changes to your Gitea repository.  

```bash
git adcom "added expansion feature"
git push
```

Quickly connect to the ArgoCD UI, & you will see that the "trident-configuration" App's status will change to "Out of Sync".  
As we have requested automatic synchronizations, ArgoCD will apply the change to your Kubernetes cluster.

```bash
$ kubectl get sc
NAME                                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
argocd-storage-class-nas (default)   csi.trident.netapp.io   Delete          Immediate           true                   3h4m
```

Done! Your infrastructure is now up to date. Time to roll out some changes on your Ghost app!

### 2. Application update: bigger volumer & new image version

We will apply a version change of the image, as well as increasing the PVC attached to the POD.

```bash
sed -i 's/5/10/' ~/Repository/Apps/Ghost/1_pvc.yaml
sed -i 's/2\.6/3\.13/' ~/Repository/Apps/Ghost/2_deploy.yaml
git adcom "ghost update to 3.13 & bigger pvc"
git push
```

As expected, ArgoCD does not apply all changes. You will need to click on the _sync_ button in the GUI.  
Also, notice that ArgoCD has identified all the objects impacted by the changes that are now in the repository.

<p align="center"><img src="Images/argocd_ghost_out_of_sync.jpg"></p>

Ghost is managed through a deployment object. A version modification will generate a new POD & terminate the existing one.  
All these changes can be following visualy in the ArgoCD UI.

<p align="center"><img src="Images/argocd_ghost_syncing.jpg"></p>

Once the update is done, you will the following:

<p align="center"><img src="Images/argocd_ghost_in_sync.jpg"></p>

& voilà!

### 3. Infrastructure update: new version of Trident

This scenario was built around Trident 21.04.0. With the availability of Trident 21.04.1 we also test its upgrade mechanism.  
The only differences between both version's manifests are located in the images to be used. Let's proceed with the changes.

```bash
sed -i 's/21.04.0/21.04.1/' ~/Repository/Infrastructure/Trident-Installer/bundle.yaml
sed -i 's/21.04.0/21.04.1/' ~/Repository/Infrastructure/Trident-Installer/trident-orchestrator.yaml
git adcom "trident update to 21.04.1"
git push
```

After a few seconds, ArgoCD will detect some differences & show the App as being out of sync.  
Again, notice the objects where the differences have been spotted.  
When you click on _Sync_, make sure you choose the following options: _Replace_ & _Apply out of Sync Only_

<p align="center"><img src="Images/argocd_trident_out_of_sync.jpg"></p>

After a few seconds (wait for the pods to restart), the App will be _Synced_ again.  

```bash
kubectl get tver -n trident
NAME      VERSION
trident   21.04.1
```

There you go, you just upgraded Trident.
