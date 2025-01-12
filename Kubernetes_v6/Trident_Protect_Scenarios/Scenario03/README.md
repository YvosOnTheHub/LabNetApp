#########################################################################################
# SCENARIO 3: S3 Bucket connectivity 
#########################################################################################

>>>The bucket custom resource (CR) for Trident protect is known as an AppVault. AppVault objects are the declarative Kubernetes workflow representation of a storage bucket. An AppVault CR contains the configurations necessary for a bucket to be used in protection operations, such as backups, snapshots, restore operations, and SnapMirror replication. Only administrators can create AppVaults.

Several applications can share the same bucket, through the same AppVault.  
If you have only one bucket available (like in this lab), one AppVault per Trident Protect is enough.  

Let's see how we can create an AppVault in the lab.  
We first need to retrieve the bucket _access key_ & _secret_.  

If you followed the scenario01 to install Trident Protect, the 2 keys can be found in the */root/ansible_S3_SVM_result.txt* file:  
```text
TASK [Print ONTAP Response for S3 User create] *********************************
ok: [localhost] => {
    "msg": [
        "SAVE THESE credentials for: S3user",
        "user access_key: EO1XP61T31I8EDGUZ1PM ",
        "user secret_key: SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx "
    ]
}
```
If you don't have this file at hand, you can connect to ONTAP in cli and retrieve the keys in advanced mode:  
```bash
cluster1::> set -priv advanced

cluster1::*> vserver object-store-server user show -vserver svm_s3
Vserver     User            ID       Key Time To Live Key Expiry Time
----------- --------------- -------- ---------------- -----------------
svm_s3      root            0        -                -
Access Key: -
Secret Key: -
   Comment: Root User
svm_s3      S3user          1        -                -
Access Key: EO1XP61T31I8EDGUZ1PM
Secret Key: SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx
   Comment:
2 entries were displayed.
```

Now that you know where to retrieve those keys, let's create variables that we will use a few times:  
```bash
BUCKETKEY=EO1XP61T31I8EDGUZ1PM
BUCKETSECRET=SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx
```
Creating an AppVault requires a secret where the keys are stored:  
```bash
kubectl create secret generic -n trident-protect s3-creds \
  --from-literal=accessKeyID=$BUCKETKEY \
  --from-literal=secretAccessKey=$BUCKETSECRET
```
You can now proceed with the AppVault creation & validation (_on both Kubernetes clusters_):  
```bash
$ tridentctl protect create appvault OntapS3 ontap-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect
$ tridentctl protect get appvault -n trident-protect
+--------------+----------+-----------+------+-------+
|     NAME     | PROVIDER |   STATE   | AGE  | ERROR |
+--------------+----------+-----------+------+-------+
|  ontap-vault | OntapS3  | Available |   3h |       |
+--------------+----------+-----------+------+-------+
```
If the bucket is listed as _available_, then the process was successful.  

You can also install a S3 browser, which can be quite useful.  
I tend to often use the one provided by AWS, which can be quite handy:  
```bash
cd
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws

mkdir ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $BUCKETKEY
aws_secret_access_key = $BUCKETSECRET
EOF
```

2 commands that could be useful to list the content of the bucket:  
```bash
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod --summarize
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod --recursive --summarize
```






