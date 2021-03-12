#########################################################################################
# ADDENDA 10: How to upgrade ONTAP
#########################################################################################

You may need to upgrade ONTAP for specific tests on this Lab-on-Demand.  
For instance, the [scenario16](../../Scenarios/Scenario16) which introduces the use of QoS requires ONTAP 9.8.  

As prerequisites, you will need to:

- download the ONTAP image with your account (image name example: **98P2_q_image.tgz**)
- download a HTTP server (example: **HFS**, found in https://www.rejetto.com/hfs/?f=dl )
- disable the Windows Firewall (otherwise, ONTAP will not manage to connect to the HTTP server)

Once the HTTP Server is running & the ONTAP image available, you can run the following steps in _cluster1_ Putty connection.

```bash
set advanced -c off
cluster image package delete 9.7P2
vol snapshot delete -vserver cluster1-01 -volume vol0 -snapshot * -force
system image update -node cluster1-01 -package  http://192.168.0.5/98P2_q_image.tgz -replace-package true -setdefault true
reboot
```

The second & third steps are here to create some space to host the 2GB file that represents the new ONTAP image.
