#########################################################################################
# ADDENDA 12: How to create a S3 Bucket on ONTAP
#########################################################################################

You may need a storage object to test some new features or products.  
This page will guide you on how to create a S3 Bucket on this Lab-on-Demand.  

As a prerequisite, you will need to update ONTAP to 9.8. The guide to do so can be found in the [addenda10](../Addenda10).
Also, ONTAP S3 being a new feature made GA with 9.8, not all mechanisms are available through REST API. Some commands also require _advanced_ mode. 
The following steps must be ran using CLI with Putty (session _cluster1_):

- Install the ONTAP S3 Licence to enable this feature
- Create a new aggregate
- Create a SVM to host the bucket
- Create a certificate
- Configure the SVM Network
- Create a S3 Bucket & an user to access it

## A. Install the ONTAP S3 License

Please contact your account team or Technical Partner Manager in order to get an ONTAP S3 evaluation license.  
Once you have it, you can install it with the following:

```bash
$ system license add -license-code ABCDEFGHIJKLMNOP
License for package "S3" installed.
(1 of 1 added successfully)
```

## B. Aggregate & SVM Creation

The aggregate creations takes about a minute to complete.

```bash
set adv -c off
storage aggregate  create  -aggregate S3 -diskcount 8 -disktype VMDISK
vserver create -vserver svm_S3 -rootvolume s3_name -aggregate S3 -rootvolume-security-style unix -language C.UTF-8 -data-services data-s3-server
```

## C. Certificate management

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
You will be asked to enter the _certificate_ & _private key_ retrieved earlier. Also, when asked to enter intermediate certificates, answer _no_. 

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

## D. Network management

We are here going to create a new service-policy that supports S3 workloads, as well as a S3 Endpoint (ie a SVM LIF) used to access the bucket we will create further out.

```bash
net int service-policy create -vserver svm_S3 -policy S3-data-policy -services data-core,data-s3-server
net int create -vserver svm_S3 -lif endpoint_S3 -service-policy S3-data-policy -address 192.168.0.230 -netmask 255.255.255.0 -home-node cluster1-01 -home-port e0e
```

## E. S3 Bucket Creation

A SVM can host one or several bucket. For this exercise, we will only create one called _s3lod_, accessible by a new user called _S3user_.

```bash
$ vserver object-store-server create -vserver svm_S3 -object-store-server ONTAP-S3.demo.netapp.com -certificate-name svm_s3_ca_166D1BCA584E5CD4_svm_s3_ca
$ vserver object-store-server bucket create -vserver svm_S3 -bucket s3lod -size 100GB
$ vserver object-store-server user create -vserver svm_S3 -user S3user

$ vserver object-store-server user show -vserver svm_S3
Vserver     User            ID        Access Key          Secret Key
----------- --------------- --------- ------------------- -------------------
svm_S3.demo.netapp.com
            root            0         -                   -
   Comment: Root User
svm_S3.demo.netapp.com
            S3user          1         zs968172_3VyrASSpz3_9_1gub_pNrZ8S4847TAtqPkgOq3pcQaAtvzjkZ2UQ4z1xIlhANKBmZfr048X4_ASZ73v7Hbz_J03wMdi2_15_dm94pyhYM__4kIQ_sYlSY6b
                                                          5Bu42Te8vmrpU_338_5Y8scvH7DI7RU3OoDM8XJsXhW867uIlXNwZN8_NCdY3hS9k49Jc_BxX8G9l_r3cBZSQ7A2C863ryW_gsl2932k36tT_HqIBu3_9Fzcy8dVM1J_

$ vserver object-store-server group create -vserver svm_S3 -name S3group -users S3user -policies FullAccess
$ vserver object-store-server bucket policy statement create -vserver svm_S3 -bucket s3lod -effect allow -action * -principal - -resource s3lod,s3lod/* -sid "" -index 1
```

The access & secret keys will be used to connect to this bucket. Keep them on the side.

## F. Testing this setup

I usually use **S3 Browser** to connect to a bucket (https://s3browser.com/).  

Here are the parameters to setup with S3 Browser when creating a new account:

- Account Type: _S3 Compatible Storage_
- REST Endpoint: the LIF created created earlier (_192.168.0.230_)
- Access Key ID & Secret Access Key: both keys gathered in the previous step
- Advanced S3-compatible storage settings: _Signature Version_ = _Signature V4_

There you go, if you configured evrything correctly, you can now access your new S3 Bucket.
