#########################################################################################
# ADDENDA 9: How to create a S3 Bucket on ONTAP
#########################################################################################

You may need a storage object to test some new features or products.  
This page will guide you on how to create a S3 Bucket on this Lab-on-Demand.  

ONTAP S3 being a new feature made GA with 9.8, not all mechanisms are available through REST API. Some commands also require _advanced_ mode. 
The following steps must be ran using CLI with Putty (session _cluster1_):  
- Create a new aggregate
- Create a SVM to host the bucket
- Create a certificate
- Configure the SVM Network
- Create a S3 Bucket & an user to access it

## A. Aggregate & SVM Creation

The aggregate creations takes about a minute to complete. You have to wait for this before creating the SVM.  
```bash
set adv -c off
storage aggregate create  -aggregate S3 -diskcount 8 -disktype VMDISK -disksize 28
vserver create -vserver svm_S3 -rootvolume s3_name -aggregate S3 -rootvolume-security-style unix -language C.UTF-8 -data-services data-s3-server
```

## B. Certificate management

Make sure you keep all the information (certificates, keys & passwords) that the CLI returns.  
This starts by the creation of a self-signed digital certificate, followed by the generation of a certificate signing request.  
```bash
$ security certificate create -vserver svm_S3 -type root-ca -common-name svm_s3_ca
The certificate s generated name for reference: svm_s3_ca_166D1BCA584E5CD4_svm_s3_ca

$ security certificate generate-csr -common-name LOD_S3

Certificate Signing Request :
-----BEGIN CERTIFICATE REQUEST-----
MIICmDCCAYACAQAwEzERMA8GA1UEAxQIWVZPU19TMzIwggEiMA0GCSqGSIb3DQEB
...
-----END CERTIFICATE REQUEST-----

Private Key :
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDeA/u/s4b0Tfk2
...
-----END PRIVATE KEY-----
```

We now need to sign the CSR to generate the S3 Server's certificate.  
You will be requested to enter the Certificate created in the previous step.  
```bash
$ security certificate sign -vserver svm_S3 -ca svm_s3_ca -ca-serial 166D1BCA584E5CD4 -expire-days 100

Please enter Certificate Signing Request(CSR): Press <Enter> when done
-----BEGIN CERTIFICATE REQUEST-----
MIICpzCCAY8CAQAwIjEgMB4GA1UEAxQXWVZPU19TMy5kZW1vLm5ldGFwcC5jb20w
...
-----END CERTIFICATE REQUEST-----

Signed Certificate :
-----BEGIN CERTIFICATE-----
MIIDMjCCAhqgAwIBAgIIFmza4TW2MjEwDQYJKoZIhvcNAQELBQAwITESMBAGA1UE
...
-----END CERTIFICATE-----
```

Last, we can now install the certificate in the S3-Enabled SVM.  
You will be asked to enter the _signed certificate_ & _private key_ retrieved earlier. Also, when asked to enter intermediate certificates, answer _no_.   
```bash
$ security certificate install -type server -vserver svm_S3
...

You should keep a copy of the private key and the CA-signed digital certificate for future reference.

The installed certificate's CA and serial number for reference:
CA: svm_s3_ca
serial: 166D1BD8B1C09F66

The certificate's generated name for reference: LOD_S3
```

Let's take a look at what we have got:  
```bash
$ security cert show -vserver svm_S3 -common-name svm_s3_ca -type root-ca -instance
  (security certificate show)
                             Vserver: svm_S3
                    Certificate Name: svm_s3_ca_166D1BCA584E5CD4_svm_s3_ca
          FQDN or Custom Common Name: svm_s3_ca
        Serial Number of Certificate: 166D1BCA584E5CD4
               Certificate Authority: svm_s3_ca
                 Type of Certificate: root-ca
 Size of Requested Certificate(bits): 2048
              Certificate Start Date: Wed Mar 17 10:53:17 2021
         Certificate Expiration Date: Thu Mar 17 10:53:17 2022
              Public Key Certificate: -----BEGIN CERTIFICATE-----
                                      MIIDWjCCAkKgAwIBAgIIFm0bylhOXNQwDQYJKoZIhvcNAQELBQAwITESMBAGA1UE
                                        ...
                                      -----END CERTIFICATE-----
        Country Name (2 letter code): US
  State or Province Name (full name):
           Locality Name (e.g. city):
    Organization Name (e.g. company):
    Organization Unit (e.g. section):
        Email Address (Contact Name):
                            Protocol: SSL
                    Hashing Function: SHA256
                             Subtype: -

```

## C. Network management

We are here going to create a new service-policy that supports S3 workloads, as well as a S3 Endpoint (ie a SVM LIF) used to access the bucket we will create further out.  
```bash
network int service-policy create -vserver svm_S3 -policy S3-data-policy -services data-core,data-s3-server
network int create -vserver svm_S3 -lif endpoint_S3 -service-policy S3-data-policy -address 192.168.0.230 -netmask 255.255.255.0 -home-node cluster1-01 -home-port e0e
```

## D. S3 Bucket Creation

A SVM can host one or several bucket. For this exercise, we will only create one called _s3lod_, accessible by a new user called _S3user_.  
```bash
$ vserver object-store-server create -vserver svm_S3 -object-store-server s3.demo.netapp.com -certificate-name LOD_S3 -is-http-enabled true
$ vserver object-store-server bucket create -vserver svm_S3 -bucket s3lod -size 100GB -storage-service-level value
$ vserver object-store-server user create -vserver svm_S3 -user S3user

$ vserver object-store-server user show -vserver svm_S3
Vserver     User            ID       Key Time To Live Key Expiry Time
----------- --------------- -------- ---------------- -----------------
svm_S3      root            0        -                -
Access Key: -
Secret Key: -
   Comment: Root User
svm_S3      S3user          1        -                -
Access Key: 32BEO512EVJ9V4CA8662
Secret Key: y9d21_p_8eDRd8PK5u_7iWWCccmA_nads4PPBamC
   Comment:
2 entries were displayed.

$ vserver object-store-server group create -vserver svm_S3 -name S3group -users S3user -policies FullAccess
$ vserver object-store-server bucket policy statement create -vserver svm_S3 -bucket s3lod -effect allow -action * -principal - -resource s3lod,s3lod/* -sid "" -index 1

$ vserver object-store-server show

Vserver: svm_S3

           Object Store Server Name: s3.demo.netapp.com
               Administrative State: up
                       HTTP Enabled: true
             Listener Port For HTTP: 80
                      HTTPS Enabled: true
     Secure Listener Port For HTTPS: 443
  Certificate for HTTPS Connections: LOD_S3
                  Default UNIX User: pcuser
               Default Windows User: -
           is-ldap-fastbind-enabled: true
                            Comment:
```

The access & secret keys will be used to connect to this bucket. Keep them on the side.

## E. Testing this setup

I usually use **S3 Browser** to connect to a bucket (https://s3browser.com/).  

Here are the parameters to setup with S3 Browser when creating a new account:  
- Account Type: _S3 Compatible Storage_
- REST Endpoint: the LIF created created earlier (_192.168.0.230_)
- Access Key ID & Secret Access Key: both keys gathered in the previous step
- Use secure transfer: uncheck the box
- Advanced S3-compatible storage settings: _Signature Version_ = _Signature V4_

There you go, if you configured everything correctly, you can now access your new S3 Bucket.
