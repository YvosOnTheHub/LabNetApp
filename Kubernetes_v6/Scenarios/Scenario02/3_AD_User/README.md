###############################################################
# SCENARIO 3: Backend configured with an AD user
###############################################################

Most Trident administrators configure a backend with a local ONTAP user.  
However, it is also possible to specify a user linked to a Domain.  
This page will guide you through the configuration of such architecture.  

The NAS SVM is already configured to serve SMB workloads, so you don't need to perform the first steps.  
You can then skip the following paragraph and start with the user creation in the AD.  

If that was not the case, here are the few commands you would have to run.  
We need to register the SVM in the Lab domain (Administrator/Netapp1!), after having configure the DNS server in the SVM.  
This can be done using the ONTAP CLI. Open a new Putty window & connect to cluster1.demo.netapp.com:  
```bash
cluster1::> vserver services dns create -vserver nassvm -domains demo.netapp.com -name-servers 192.168.0.253 
cluster1::> vserver active-directory create -vserver nassvm -account-name nassvm -domain demo.netapp.com

cluster1::> vserver active-directory show
            Account         Domain/Workgroup
Vserver     Name            Name
----------- --------------- ----------------
nassvm      NFSSVM          DEMO
```

We now need to create a new user (called _trident_ in my example) in the Active Directory.  
This could be done in 2 ways:
- Open a Remote Desktop Connection onto _DC1_ and then use the Server Manager window  
- Open a Powershell window on the lab desktop and create a user remotely

Here are the commands to run for the second method:
```posh
> Invoke-Command -ComputerName DC1 -Scriptblock { New-ADUser trident -AccountPassword(ConvertTo-SecureString -AsPlainText “Netapp1!” -Force) -ChangePasswordAtLogon $False -Enabled $true -GivenName NetApp -Surname Trident -OtherAttributes @{mail="trident@demo.netapp.com"} }
> Invoke-Command -ComputerName DC1 -Scriptblock { Get-ADUser -Identity trident -Properties * } | select givenname,surname,mail,enabled
GivenName Surname mail                    Enabled
--------- ------- ----                    -------
NetApp    Trident trident@demo.netapp.com    True
```

Back to ONTAP, this _trident_ user needs to be associates with a specific role (_vsadmin_) and specific applications (_http_ and _ontapi_). Note that I added _ssh_ which is not required for Trident, but can help to test that this AD user is functional.  
```bash
cluster1::> security login create -user-or-group-name DEMO\trident -application http -authentication-method domain -role vsadmin -vserver nassvm   
cluster1::> security login create -user-or-group-name DEMO\trident -application ontapi -authentication-method domain -role vsadmin -vserver nassvm
cluster1::> security login create -user-or-group-name DEMO\trident -application ssh -authentication-method domain -role vsadmin -vserver nassvm

cluster1::> security login show -vserver nassvm -user-or-group-name DEMO\trident

Vserver: nassvm
                                                                 Second
User/Group                 Authentication                 Acct   Authentication
Name           Application Method        Role Name        Locked Method
-------------- ----------- ------------- ---------------- ------ --------------
DEMO\trident   http        domain        vsadmin          -      none
DEMO\trident   ontapi      domain        vsadmin          -      none
DEMO\trident   ssh         domain        vsadmin          -      none
3 entries were displayed.
```

You can check if this configuration is functional by trying to connect to the SVM via SSH (you need two '\\', this is not a typo):
```bash
ssh -l DEMO\\trident 192.168.0.133
```

If this worked, you can proceed with the the final steps, which are to just configure a new Trident backend & the corresponding storage class.  
```bash
$ kubectl create -n trident -f secret-ontap-nfs-svm-domain.yaml
secret/ontap-nfs-svm-secret-domain created

$ kubectl create -n trident -f backend-nas-domain.yaml
tridentbackendconfig.trident.netapp.io/backend-tbc-ontap-nas-domain created

$ kubectl get tbc -n trident backend-tbc-ontap-nas-domain
NAME                           BACKEND NAME   BACKEND UUID                           PHASE   STATUS
backend-tbc-ontap-nas-domain   nas-domain     d63f4f46-587b-4cac-9319-55d5b543abf6   Bound   Success

$ kubectl create -f sc-csi-ontap-nas-domain.yaml
storageclass.storage.k8s.io/storage-class-nas-domain created
```

There you go, you can now create volumes with this backend, or check other scenarios:  
- [Scenario03](../../Scenario03): Install Prometheus & Grafana  
- [Scenario04](../../Scenario04): Deploy your first app with File storage  

Or go back to the [FrontPage](https://github.com/YvosOnTheHub/LabNetApp)

