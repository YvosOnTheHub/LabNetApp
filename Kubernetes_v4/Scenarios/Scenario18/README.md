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

The prerequisites of this lab are the following:

- Completly uninstall Trident (there is a script called _trident_uninstall.sh_ in this folder that will do it for you)
- Install the Load Balancer [MetalLB](../../Addendum/Addenda05)
- Install the lightweight Git repository [Gitea](../../Addendum/Addenda13) (paragraph #A) & create an admin user (demo/netapp123)
- Install the continuous deployment tool [ArgoCD](../../Addendum/Addenda14)

## A. Docker images

The first part of this scenario is about managing Trident images. This will be done in 3 successive steps:  

- Pull Trident images from the Docker Hub
- Tag these images
- Push them to the local registry  

You will find in this folder a script called _push_scenario_images_to_private_repo.sh_ that will do the job for you.  
Refer to the chapter [Addenda09](../../Addendum/Addenda09) to learn more about Docker images management, as it may require you to use your own login.

## B. Gitea repository

Let's first create a new repository in Gitea:

```bash
curl -X POST "http://gitea.demo.netapp.com:3000/api/v1/user/repos" -u demo:netapp123 -H "accept: application/json" -H "content-type: application/json" -d '{
  "name":"scenario18",
  "description": "argocd repo"
}'
```

Now, you can setup your local Git parameters:

```bash
git config --global user.email lod.demo.netapp.com
git config --global user.name "lod"
git config --global credential.helper store
git config --global alias.adcom '!git add -A && git commit -m'
git config --global push.default simple
```

You will find here a folder called _Repository_ that will we use as a base. Feel free to add your own apps in there for the sake of fun!  
The following will push the data to the newly created repository. Once pushed, you can connect to the Gitea UI & see the result.

```bash
cp -R ~/LabNetApp/Kubernetes_v4/Scenarios/Scenario18/Repository ~/
cd ~/Repository
git init
git add .
git commit -m "initial commit"
git remote add origin http://gitea.demo.netapp.com:3000/demo/scenario18.git
git push -u origin master
```

& now the fun starts!

## C. ArgoCD configuration
