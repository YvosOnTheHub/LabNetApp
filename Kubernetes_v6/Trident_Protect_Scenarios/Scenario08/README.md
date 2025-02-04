#########################################################################################
# SCENARIO 8: Protecting Applications & GitOps 
#########################################################################################  

Trident Protect was first designed to be used in a declarative way.  
It makes it very easy to add a protection manifest while deploying an application so that it is automatically protected.  
You can also use the same logic to manage the DR of your applications.  

We will cover such scenario here with Wordpress & ArgoCD.  


## A. Prerequisites

The prerequisites of this lab are the following:  
- Install the lightweight Git repository [Gitea](../../Addendum/Addenda10) (only the paragraph #A) & create an admin user (demo/netapp123)  
- Install the continuous deployment tool [ArgoCD](../../Addendum/Addenda11)  

You will also find in this folder a script called _push_scenario_images_to_private_repo.sh_ that will retrieve the scenario images & push them to the lab repository.  
Refer to the chapter [Addenda08](../../Addendum/Addenda08) to learn more about Docker images management, as it may require you to use your own login.  

## B. Setup

Let's first create a new repository in Gitea:  
```bash
curl -X POST "http://192.168.0.65:3000/api/v1/user/repos" -u demo:netapp123 -H "accept: application/json" -H "content-type: application/json" -d '{
  "name":"wordpress",
  "description": "wordpress repo for Trident Protect demos"
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

## C. Push data to the Git repo

You will find here a folder called _Repository_ that will be used as a base. Feel free to add your own apps in there for the sake of fun!  
The following will push the data to the newly created repository (user/pwd: demo/netapp123).  
Once pushed, you can connect to the Gitea UI & see the result.  
```bash
cp -R ~/LabNetApp/Kubernetes_v6/Trident_Protect_Scenarios/Scenario08/Repository ~/
cd ~/Repository
git init
git add .
git commit -m "initial commit"
git remote add origin http://192.168.0.65:3000/demo/wordpress.git
git push -u origin master
```
& now the fun starts!

You can try 2 different scenarios:  
[1.](./1_Snapshot/) Automatically apply protections policies to your application  
[2.](./2_DR/) Automatically setup the DR of an application    
