#########################################################################################
# SCENARIO 15.2: NFS Showmount
#########################################################################################  

Unix hosts often have a very useful program called _showmount_.  
A person can just run this command against a NFS server to see what volumes are currently exported & available to be mounted.
Depending on who has access to these hosts, this can be seen as a security hole.  

This feature is enabled on the SVM called _SVM1_. Let's see what we get:

```bash
$ showmount -e 192.168.0.135
Export list for 192.168.0.135:
/nas1_pvc_04a9ce10_a7e8_4747_8673_fa5a2f762a1d    (everyone)
/nas1_pvc_7f9f3ba2_7222_4f38_bf86_224a7f37b69a    (everyone)
/nas1_pvc_7fa51ef2_1196_4b0a_ae18_8792af6d52eb    (everyone)
/nas1_pvc_f2b2b16f_db6b_4562_9702_15b285026d79    (everyone)
/registry                                         (everyone)
/                                                 (everyone)
/vol_import_manage                                (everyone)
/vol_import_nomanage                              (everyone)
/www                                              (everyone)
```

The new SVM we just created does not have any volume, aside from the root one. Here is what you could get with the showmount command:

```bash
$ showmount -e 192.168.0.211
Export list for 192.168.0.211:
/ (everyone)
```

Now that we know what resources are available, one could very well mount one of these volumes, granted the export policy allow them to do so.  

The storage admin can disable this feature on the backend, in order to avoid getting such list.  
We will again use an ansible script to do so, on the SVM we created for this exercise:

```bash
$ ansible-playbook svm_secured_showmount.yaml
PLAY [localhost]
TASK [Gathering Facts]
TASK [Disable Showmount]
PLAY RECAP
localhost                  : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Now, if you try to list the exported volumes, you will receive an empty result:

```bash
$ showmount -e 192.168.0.211
Export list for 192.168.0.211:
```

Notice I used the NFS LIF (IP 211), as the Management LIF (IP 210) does not have NFS capability on this SVM.


## What's next

You shoud continue with:

- [Trident Configuration](../3_Trident_Configuration): Let's use Trident on the secured storage tenant  

Or go back to:

- the [Scenario15 FrontPage](../)
- the [GitHub FrontPage](https://github.com/YvosOnTheHub/LabNetApp)